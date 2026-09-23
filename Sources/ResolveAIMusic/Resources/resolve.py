"""Trusted, fixed Resolve script. Request is JSON injected by the native bridge."""
import json


def ensure(condition, message):
    if not condition:
        raise ValueError(message)


def owned(item):
    return any(str(marker.get('customData', '')).startswith('resolve-ai-music:')
               for marker in (item.GetMarkers() or {}).values())


def clip_info(item):
    media = item.GetMediaPoolItem()
    return {'id': item.GetUniqueId(), 'name': item.GetName(),
            'start': item.GetStart(True), 'end': item.GetEnd(True),
            'managed': owned(item),
            'path': media.GetClipProperty('File Path') if media else ''}


def snapshot():
    ensure(project, '没有打开的 Resolve 项目。')
    timeline = project.GetCurrentTimeline()
    ensure(timeline, '没有打开的时间线。')
    settings = timeline.GetSettings()
    fps = float(str(settings.get('timelineFrameRate', '24')).split()[0])
    return {'projectId': project.GetUniqueId(), 'projectName': project.GetName(),
            'timelineId': timeline.GetUniqueId(), 'timelineName': timeline.GetName(),
            'frameRate': fps, 'startFrame': timeline.GetStartFrame(),
            'timecode': timeline.GetCurrentTimecode(), 'marks': timeline.GetMarkInOut() or {},
            'tracks': [{'index': index, 'name': timeline.GetTrackName('audio', index),
                        'locked': timeline.GetIsTrackLocked('audio', index),
                        'clips': [clip_info(item) for item in timeline.GetItemListInTrack('audio', index) or []]}
                       for index in range(1, timeline.GetTrackCount('audio') + 1)]}


def perform(req):
    current = snapshot()
    if req['action'] == 'snapshot':
        return current
    expected = req['session']
    ensure(current['projectId'] == expected['projectId'] and
           current['timelineId'] == expected['timelineId'], '项目或时间线已切换；音频已保留，请重新选择目标。')
    ensure(current['frameRate'] == expected['frameRate'] and current['startFrame'] == expected['startFrame'],
           '时间线帧率或起始时间已变化，请重新检查后插入。')
    timeline = project.GetCurrentTimeline()
    if req['action'] == 'locate':
        ensure(timeline.SetCurrentTimecode(req.get('timecode', expected['timecode'])), '无法定位播放头。')
        return {'ok': True}
    pair = int(req['pair'])
    ensure(pair >= 3, '目标轨道必须从 A3 开始。')
    for index in [pair, pair + 1]:
        before = next((t for t in expected['tracks'] if t['index'] == index), None)
        now = next((t for t in current['tracks'] if t['index'] == index), None)
        ensure(now == before, '生成期间目标轨道发生变化，已暂停写入；可重新检查后插入已下载音频。')
        if now:
            ensure(not now['locked'] and all(c['managed'] for c in now['clips']), '目标轨含非应用音频或已锁定。')
    start = req['range']['start']
    frames = req['range']['frames']
    ensure(frames > 0, '无效区间。')
    slots = []
    for index in [pair, pair + 1]:
        items = timeline.GetItemListInTrack('audio', index) or [] if index <= timeline.GetTrackCount('audio') else []
        hits = [c for c in items if c.GetStart(True) < start + frames and c.GetEnd(True) > start]
        ensure(len(hits) <= 1, '区间内有多个音乐片段，请调整 In-Out。')
        for item in hits:
            ensure(abs(item.GetStart(True) - start) < 0.01 and abs(item.GetDuration(True) - frames) < 0.01,
                   '选区与已有音乐部分重叠；请使用原片段完整区间。')
        slots.append(hits[0] if hits else None)
    if req['action'] == 'swap':
        ensure(slots[1], '当前区间没有备选版本。')
    pool = project.GetMediaPool()
    new_media = None
    if req['action'] == 'insert':
        media = pool.ImportMedia([req['path']])
        ensure(media and len(media) == 1, '音频导入失败；原音乐未修改。')
        new_media = media[0]
    alternate_only = req.get('targetRole') == 'alternate' and req['action'] == 'insert'
    ensure(req['action'] in ['insert', 'swap'], '不支持的操作。')
    # Snapshot before the first destructive operation, retained for manual recovery.
    backup_name = timeline.GetName() + ' · AI backup ' + req['operationId'][:8]
    backup = timeline.DuplicateTimeline(backup_name)
    ensure(backup, '无法创建恢复备份，停止写入。')
    ensure(project.SetCurrentTimeline(timeline), '无法恢复原时间线。')
    records = []
    for item in slots:
        records.append(None if item is None else {
            'media': item.GetMediaPoolItem(), 'source': item.GetSourceStartFrame(),
            'name': item.GetName(), 'enabled': item.GetClipEnabled()})
    created = []
    removed = False

    def append(record, track, enabled):
        clips = pool.AppendToTimeline([{'mediaPoolItem': record['media'],
                                       'startFrame': record['source'],
                                       # Resolve 21.1 audio-only insertion uses an exclusive end frame.
                                       'endFrame': record['source'] + frames,
                                       'mediaType': 2, 'trackIndex': track, 'recordFrame': start}])
        ensure(clips and len(clips) == 1, '插入失败。')
        item = clips[0]
        created.append(item)
        ensure(abs(item.GetStart(True) - start) < 0.01 and abs(item.GetDuration(True) - frames) < 0.01,
               '插入校验失败：start=' + str(item.GetStart(True)) + ', duration=' + str(item.GetDuration(True))
               + ', expected=' + str(start) + '/' + str(frames))
        ensure(item.SetClipEnabled(enabled), '设置主备播放状态失败。')
        ensure(item.AddMarker(0, 'Purple' if track == pair else 'Blue', 'AI Music', '', 1,
                              'resolve-ai-music:' + req['operationId']), '无法标记片段归属。')
        return item

    try:
        while timeline.GetTrackCount('audio') < pair + 1:
            ensure(timeline.AddTrack('audio', 'stereo'), '无法创建立体声音轨。')
        ensure(timeline.SetTrackName('audio', pair, 'AI MUSIC · 主版本'), '轨道命名失败。')
        ensure(timeline.SetTrackName('audio', pair + 1, 'AI MUSIC · 备选版本'), '轨道命名失败。')
        to_remove = [slots[1]] if alternate_only and slots[1] else ([] if alternate_only else [item for item in slots if item])
        if to_remove:
            removed = True
            ensure(timeline.DeleteClips(to_remove, False), '旧版本移除失败。')
        if new_media:
            append({'media': new_media, 'source': 0}, pair + 1 if alternate_only else pair, not alternate_only)
            if records[0] and not alternate_only:
                append(records[0], pair + 1, False)
        else:
            append(records[1], pair, True)
            if records[0]:
                append(records[0], pair + 1, False)
        return {'ok': True, 'backup': backup_name, 'snapshot': snapshot()}
    except Exception as error:
        # Recovery is explicit: the complete pre-edit timeline remains accessible even if rollback fails.
        try:
            if created:
                ensure(timeline.DeleteClips(created, False), '回滚清理失败。')
            if removed:
                for offset, record in enumerate(records):
                    if record:
                        # Re-query prevents duplicating an old clip after partial deletion.
                        existing = timeline.GetItemListInTrack('audio', pair + offset) or []
                        if not any(abs(c.GetStart(True) - start) < 0.01 for c in existing):
                            append(record, pair + offset, record['enabled'])
        except Exception:
            raise ValueError(str(error) + ' 自动回滚未完成，请使用备份时间线：' + backup_name)
        raise ValueError(str(error) + ' 原版本已恢复；备份：' + backup_name)


result = perform(request)
