# G11 路线动作入口验证

在当前museum场景使用真实Viewport.push_input鼠标按下/释放：普通路点依次选等待、蹲行、疾跑、普通；把既有mask移至已知格作为测试夹具，确认拿取可选并进入路线时间轴，再真实按空格执行并验证目标入包。这是输入路由回归，不冒充从新档实际探索取物。

修复前：9项中5项失败，原始before.log；初次受限环境另有user日志目录写入错误，未计为逻辑缺陷。修复后使用--log-file /tmp/thief_g11_engine.log，after.log 12/12且无引擎错误。

完整命令：~/.local/bin/godot --headless --log-file /tmp/thief_g11_engine.log res://tests/test_plan_actions.tscn

全量首次：TMPDIR=/tmp/thief_goal_g11 tools/verify.sh。受限环境的编辑器配置/日志写入错误，以及并行test_museum_sim新增camera_ok类型推断解析错误，无法代表完整玩法结果。核实父子进程后只终止本轮验证277132/277726，原始verify_interrupted.log；待负责人修复后在可运行环境重跑。
