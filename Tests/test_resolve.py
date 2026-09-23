"""Fault-injection tests of the same script shipped in the app. No Resolve writes."""
import pathlib
import unittest

SCRIPT = (pathlib.Path(__file__).parents[1] / 'Sources/ResolveAIMusic/Resources/resolve.py').read_text()


class Media:
    def __init__(self, path):
        self.path = path

    def GetClipProperty(self, key):
        return self.path


class Clip:
    sequence = 0

    def __init__(self, media, start=100, end=580, managed=True):
        Clip.sequence += 1
        self.id = str(Clip.sequence)
        self.media, self.start, self.end = media, start, end
        self.managed, self.enabled = managed, True

    def GetUniqueId(self): return self.id
    def GetName(self): return self.media.path
    def GetMediaPoolItem(self): return self.media
    def GetStart(self, *args): return self.start
    def GetEnd(self, *args): return self.end
    def GetDuration(self, *args): return self.end - self.start
    def GetSourceStartFrame(self): return 0
    def GetClipEnabled(self): return self.enabled
    def GetMarkers(self): return {0: {'customData': 'resolve-ai-music:test'}} if self.managed else {}
    def SetClipEnabled(self, enabled):
        self.enabled = enabled
        return True
    def AddMarker(self, *args):
        self.managed = True
        return True


class Timeline:
    def __init__(self):
        self.tracks = {i: [] for i in range(1, 5)}
        self.names = {i: '' for i in range(1, 5)}
        self.backups = []

    def GetUniqueId(self): return 'timeline'
    def GetName(self): return 'Test'
    def GetSettings(self): return {'timelineFrameRate': '24'}
    def GetStartFrame(self): return 0
    def GetCurrentTimecode(self): return '00:00:04:04'
    def GetMarkInOut(self): return {}
    def GetTrackCount(self, kind): return len(self.tracks)
    def GetTrackName(self, kind, index): return self.names[index]
    def GetIsTrackLocked(self, *args): return False
    def GetItemListInTrack(self, kind, index): return self.tracks[index][:]
    def AddTrack(self, *args):
        index = len(self.tracks) + 1
        self.tracks[index], self.names[index] = [], ''
        return True
    def SetTrackName(self, kind, index, name):
        self.names[index] = name
        return True
    def DuplicateTimeline(self, name):
        self.backups.append(name)
        return object()
    def DeleteClips(self, items, ripple):
        assert not ripple
        for index in self.tracks:
            self.tracks[index] = [c for c in self.tracks[index] if c not in items]
        return True


class Pool:
    def __init__(self, timeline):
        self.timeline = timeline
        self.fail_next = False
    def ImportMedia(self, paths): return [Media(paths[0])]
    def AppendToTimeline(self, values):
        if self.fail_next:
            self.fail_next = False
            return []
        value = values[0]
        clip = Clip(value['mediaPoolItem'], value['recordFrame'],
                    value['recordFrame'] + value['endFrame'] - value['startFrame'])
        self.timeline.tracks[value['trackIndex']].append(clip)
        return [clip]


class Project:
    def __init__(self):
        self.timeline = Timeline()
        self.pool = Pool(self.timeline)
    def GetUniqueId(self): return 'project'
    def GetName(self): return 'Test'
    def GetCurrentTimeline(self): return self.timeline
    def GetMediaPool(self): return self.pool
    def SetCurrentTimeline(self, timeline): return timeline is self.timeline


class ResolveTests(unittest.TestCase):
    def setUp(self):
        self.project = Project()
        self.context = {'project': self.project, 'request': {'action': 'snapshot'}}
        exec(compile(SCRIPT, 'resolve.py', 'exec'), self.context)

    def req(self, action='insert'):
        return {'action': action, 'session': self.context['snapshot'](), 'range': {'start': 100, 'frames': 480},
                'pair': 3, 'path': 'new.wav', 'operationId': '12345678-test'}

    def run_request(self, request):
        return self.context['perform'](request)

    def test_rotation_and_swap(self):
        self.run_request(self.req())
        first = self.project.timeline.tracks[3][0]
        self.run_request(self.req())
        self.assertFalse(self.project.timeline.tracks[4][0].enabled)
        self.assertEqual(self.project.timeline.tracks[4][0].media, first.media)
        self.run_request(self.req('swap'))
        self.assertEqual(self.project.timeline.tracks[3][0].media, first.media)
        self.assertTrue(self.project.timeline.tracks[3][0].enabled)
        self.assertFalse(self.project.timeline.tracks[4][0].enabled)

    def test_failed_insert_restores_original(self):
        self.run_request(self.req())
        old = self.project.timeline.tracks[3][0].media
        self.project.pool.fail_next = True
        with self.assertRaises(ValueError): self.run_request(self.req())
        self.assertEqual(self.project.timeline.tracks[3][0].media, old)
        self.assertEqual(len(self.project.timeline.backups), 2)

    def test_foreign_clip_never_deleted(self):
        clip = Clip(Media('voice.wav'), managed=False)
        self.project.timeline.tracks[3].append(clip)
        with self.assertRaises(ValueError): self.run_request(self.req())
        self.assertEqual(self.project.timeline.tracks[3], [clip])
        self.assertFalse(self.project.timeline.backups)

    def test_timeline_changed_after_request(self):
        request = self.req()
        self.project.timeline.tracks[3].append(Clip(Media('changed.wav')))
        with self.assertRaises(ValueError): self.run_request(request)

    def test_partial_overlap_rejected(self):
        self.project.timeline.tracks[3].append(Clip(Media('old.wav'), start=99))
        with self.assertRaises(ValueError): self.run_request(self.req())

    def test_alternate_does_not_replace_main(self):
        self.run_request(self.req())
        original = self.project.timeline.tracks[3][0]
        request = self.req()
        request['targetRole'] = 'alternate'
        self.run_request(request)
        self.assertIs(self.project.timeline.tracks[3][0], original)
        self.assertFalse(self.project.timeline.tracks[4][0].enabled)

    def test_alternate_first_can_be_adopted(self):
        request = self.req()
        request['targetRole'] = 'alternate'
        self.run_request(request)
        self.assertEqual(self.project.timeline.tracks[3], [])
        self.run_request(self.req('swap'))
        self.assertEqual(len(self.project.timeline.tracks[3]), 1)
        self.assertTrue(self.project.timeline.tracks[3][0].enabled)
        self.assertEqual(self.project.timeline.tracks[4], [])


if __name__ == '__main__':
    unittest.main()
