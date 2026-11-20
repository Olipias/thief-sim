"""python3 -m unittest discover -s tests -p test_agent_link.py -v"""
import importlib.util
from pathlib import Path
import tempfile
import unittest
s=importlib.util.spec_from_file_location('link',Path(__file__).parents[1]/'tools/agent_link.py')
link=importlib.util.module_from_spec(s);s.loader.exec_module(link)

class LinkTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.db=link.db_open(Path(self.tmp.name)/'queue.sqlite')
        self.cfg={'channel':'thief','targets':{'plan':{'owner':'agent-link','session':'session1'},'code':{'owner':'external','session':'session2'}}}
    def tearDown(self):self.db.close();self.tmp.cleanup()
    def msg(self,i,text,sender='codex',kind='chat'):return {'id':i,'text':text,'sender':sender,'type':kind}
    def test_mentions(self):
        self.assertEqual(link.mentions('@plan @planner `@code` ```@all``` foo@art'),{'plan','planner'})
    def test_self_system_external(self):
        link.ingest(self.db,self.cfg,[self.msg(1,'@plan','plan'),self.msg(2,'@plan',kind='join'),self.msg(3,'@code')])
        self.assertEqual(self.db.execute('select count(*) from wakes').fetchone()[0],0)
    def test_all_and_bursts(self):
        msgs=[self.msg(i,'@all') for i in range(1,120)]
        link.ingest(self.db,self.cfg,msgs);link.ingest(self.db,self.cfg,msgs)
        self.assertEqual(self.db.execute('select count(*) from wakes').fetchone()[0],119)
        calls=[];link.deliver(self.db,self.cfg,lambda *a:calls.append(a),now=100)
        self.assertEqual(len(calls),1)
        self.assertEqual(self.db.execute("select count(*) from wakes where status='submitted'").fetchone()[0],119)
    def test_failure_retry_durable(self):
        link.ingest(self.db,self.cfg,[self.msg(1,'@plan')])
        def fail(*_):raise TimeoutError('private text never persisted')
        link.deliver(self.db,self.cfg,fail,now=100)
        self.assertEqual(self.db.execute('select status,attempts,error from wakes').fetchone(),('pending',1,'TimeoutError'))
        self.db.close();self.db=link.db_open(Path(self.tmp.name)/'queue.sqlite')
        calls=[];link.deliver(self.db,self.cfg,lambda *a:calls.append(a),now=101)
        self.assertFalse(calls)
        link.deliver(self.db,self.cfg,lambda *a:calls.append(a),now=111)
        self.assertEqual(len(calls),1)
    def test_cooldown_queues_instead_of_drops(self):
        calls=[]
        link.ingest(self.db,self.cfg,[self.msg(1,'@plan')]);link.deliver(self.db,self.cfg,lambda *a:calls.append(a),now=100)
        link.ingest(self.db,self.cfg,[self.msg(2,'@plan')]);link.deliver(self.db,self.cfg,lambda *a:calls.append(a),now=101)
        self.assertEqual(self.db.execute("select status from wakes where mid=2").fetchone()[0],'pending')
        link.deliver(self.db,self.cfg,lambda *a:calls.append(a),now=111)
        self.assertEqual(len(calls),2)
    def test_ack_not_automatic(self):
        link.ingest(self.db,self.cfg,[self.msg(1,'@plan')]);link.deliver(self.db,self.cfg,lambda *_:None,now=100)
        self.assertEqual(self.db.execute('select count(*) from receipts').fetchone()[0],0)
    def test_credentials_private(self):
        p=Path(self.tmp.name)/'secret.json';link.atomic_json(p,{'token':'private'})
        self.assertEqual(p.stat().st_mode & 0o777,0o600)
if __name__=='__main__':unittest.main()
