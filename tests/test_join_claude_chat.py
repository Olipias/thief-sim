import importlib.util
from pathlib import Path
import tempfile
import unittest
s=importlib.util.spec_from_file_location('join',Path(__file__).parents[1]/'tools/join_claude_chat.py')
m=importlib.util.module_from_spec(s);s.loader.exec_module(m)

class JoinTests(unittest.TestCase):
    def test_project_directory_override_without_global_mutation(self):
        original={'agents':{'claude':{'cwd':'..','command':'claude'},'codex':{'cwd':'..'}}}
        result=m.scoped_config(lambda *_:original,Path('/tmp/project'))()
        self.assertEqual(result['agents']['claude']['cwd'],'/tmp/project')
        self.assertEqual(original['agents']['claude']['cwd'],'..')
        self.assertEqual(result['agents']['codex'],original['agents']['codex'])
    def test_resume_and_restart_arguments(self):
        args=m.launch_args('731ee90d-1e5b-486a-962f-81a2664c6fa3')
        self.assertIn('--no-restart',args)
        self.assertEqual(args[-2:],['--resume','731ee90d-1e5b-486a-962f-81a2664c6fa3'])
        self.assertEqual(m.launch_args(None)[-1],'--resume')
    def test_history_is_scoped_and_read_without_contents(self):
        with tempfile.TemporaryDirectory() as home:
            project=Path('/tmp/specific-project')
            directory=Path(home)/'.claude/projects/-tmp-specific-project'
            directory.mkdir(parents=True)
            path=directory/'731ee90d-1e5b-486a-962f-81a2664c6fa3.jsonl'
            path.write_text('not parsed')
            (directory/'not-a-session.jsonl').write_text('ignored')
            self.assertEqual(m.sessions(project,home),[path])
if __name__=='__main__':unittest.main()
