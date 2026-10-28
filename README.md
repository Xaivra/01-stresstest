# 龙控1号 V8 通信与 IO 测试

本目录包含网口、RS485、DIDO 和继电器测试源码，以及统一调度器。它覆盖这些接口的回路测试，不代表整本出厂手册中的 RTC、CAN、Wi-Fi、4G、存储等项目已通过。

## 快速使用

把构建出的 `eth_test_tool`、`rs485_tool`、`dio_tool`、`ems_test_runner`、`config.example.json`、`run_all_parallel_tests.sh` 六个文件放在同一目录。目标系统为 ARM Linux；以 root 运行：

预压测和完整压测另外打包 `run_pre_stress.sh`、`run_full_stress.sh`，共8个运行文件。

```sh
# 预压测：每个已启用任务10次
sh ./run_pre_stress.sh
# 长时间压测：每个已启用任务10000次，不适用于半小时要求
sh ./run_full_stress.sh
# 开始前只查看计划，不操作硬件
sh ./run_full_stress.sh --dry-run
```

两个入口固定各项次数，覆盖配置中每对、每通道的次数；也不接受命令行另改次数。可传入 `-c`、`--output-dir`、`--jobs`、`--timeout` 等其他选项。继电器仍按配置开关决定是否执行，默认跳过。需自定义次数时使用 `run_all_parallel_tests.sh`。

次数含义保持不变：网口和RS485为每方向包数，DIDO及继电器为每通道完整诊断周期数。按默认100ms的DIDO图样间隔，8通道10000个周期约需4小时43分钟，实际受IO和存储耗时影响；启用继电器时，其10000个周期按默认500ms采样等待加1000ms间隔约需37小时30分钟。

```sh
chmod +x eth_test_tool rs485_tool dio_tool ems_test_runner run_all_parallel_tests.sh
# 只查看任务、实际参数和超时，不操作硬件，也不生成日志
./run_all_parallel_tests.sh --dry-run
# 检查基本设备、运行时间；详细 GPIO 请求及物理链路由工具启动时检查
./run_all_parallel_tests.sh --precheck-only
# 接好回路后短测：网口每方向100包，RS485每方向100包，DIDO各2个完整诊断周期
./run_all_parallel_tests.sh --eth-count 100 --rs485-count 100 --dido-count 2
# 全部测试项统一次数，或指定配置和日志目录
./run_all_parallel_tests.sh --iterations 10 -c ./config.example.json --output-dir /mnt/sdcard
```

脚本按自身位置寻找调度器和默认配置，支持从其他工作目录启动。`--bin-dir DIR` 可指定工具目录。`--jobs N` 控制并发数；默认8、最大32。网口和不同串口对可并行，DIDO与继电器互斥运行。

## 半小时完整压测推荐方案

接好测试回路后，使用以下次数，目标在半小时内完成，并预留约5分钟余量：

| 测试项 | 次数 | 默认参数下预计耗时 |
|---|---:|---:|
| 网口 | 每对接口、每方向7500包 | 约25分钟 |
| RS485 | 每对串口、每方向7500包 | 约25分钟 |
| DIDO | 每路800个完整诊断周期 | 约22分40秒 |
| 继电器 | 保持关闭，跳过 | 不执行 |

```sh
sh ./run_all_parallel_tests.sh \
  --eth-count 7500 \
  --rs485-count 7500 \
  --dido-count 800 \
  --timeout 1800
```

以上估算基于当前默认的2对网口、5对RS485、8路DIDO、100ms通信发送间隔、100ms DIDO图样间隔，以及默认8个并发任务。各项并行运行，整体预计约25分钟；实际耗时受硬件、IO及日志写入影响。

`--timeout 1800` 是半小时硬上限，达到上限时中止剩余任务并判失败，不能将中止视为测试完成。此方案要求 `dio.relay_enabled` 保持 `false`；启用继电器或降低并发数后需重新估算耗时。

`run_full_stress.sh` 仍固定为各项10000次，不适用于半小时方案；请使用上面的 `run_all_parallel_tests.sh` 命令。

## 次数与开关

优先级从高到低：测试项命令行参数（如 `--rs485-count`）、统一 `--iterations`、每对/每通道的 `iterations`、所属测试项的次数、顶层默认次数。

| 测试项 | 配置次数 | 单点次数 |
|---|---|---|
| 网口 | `ethernet.iterations` | `ethernet.pairs[i].iterations` |
| RS485 | `rs485.iterations` | `rs485.pairs[i].iterations` |
| DIDO | `dio.iterations` | `dio.do_map[i].iterations` |
| 继电器 | `dio.relay_iterations`，省略时取 `dio.iterations` | `dio.relay_map[i].iterations` |

网口、RS485次数表示**每个方向**的包数。GPIO次数表示目标通道完成一次 walking-one 和 walking-zero 检查的**完整诊断周期数**，每个周期开始还检查全低状态。测试其他目标通道时，所有反馈仍继续接受检查，输出也会随诊断图样变化；次数不是物理翻转边沿数。该诊断比旧版全通道同时翻转耗时更长，首次请用小次数检查接线。

在某一对串口或网口的对象中增加 `"iterations": 200` 即可独立设置。通道对象示例：

```json
{"name": "DO1", "chip": "gpiochip2", "line": 0, "iterations": 5}
```

`ethernet.enabled`、`rs485.enabled`、`dio.enabled` 控制类别；`dio.dido_enabled` 和 `dio.relay_enabled` 分别控制两个 GPIO 模式。网口、RS485的每个 `pairs` 对象也支持 `enabled`。禁用任务会记录为跳过，不会运行。全部禁用会报配置错误。

当前示例配置默认关闭继电器回路测试（`dio.relay_enabled: false`）。确认触点供电及反馈接线后，将其改为 `true` 才会纳入全量测试；仅设置 `--relay-count` 不会启用该测试。所有回路测试均须先确认接线，程序返回通过不能代替接线及测试条件确认。

直接运行 `rs485_tool -c FILE`、`eth_test_tool -c FILE` 也支持类别默认参数和命令行覆盖；每对次数请通过调度器运行。DIO直接调用支持每通道次数；`--iterations` 会覆盖本次模式中所有通道的次数。

## 接线与启动条件

- V8默认网口为 `eth0↔lan2`、`lan3↔lan4`。使用二层原始帧及严格物理链路检查，不通过本机IP路由代替网线测试。无需为回路接口配置同网段IP。
- RS485保持手册原映射：1↔2、3↔4、5↔6、7↔8、9↔10，各对A接A、B接B。6号口是 `/dev/ttyCH9344USB4`；7至10号依次为USB0至USB3。
- DIDO要求DO1至DO8分别接对应DI，并具备手册要求的电源、使能和负载条件。逐路诊断可检测反馈接反、部分通道短接及固定高低电平。
- 继电器测试要求触点外部供电并把4路触点反馈连接至DI1至DI4；继电器控制GPIO不是触点反馈输入。DIDO与继电器反馈接线应使用兼容的测试夹具，或通过开关只运行当前已接好的模式。
- `strict_no_check` 默认关闭，`no_map` 默认空。启用时必须提供独立反馈GPIO；与DO、DI重叠，或与继电器控制引脚重合的配置会被拒绝。关闭时仅DO→DI结果参与DIDO判定，CSV反馈值`-2`表示未启用。
- GPIO测试须开机至少80秒。工具不会自动切换业务模式、复位USB或修改网卡配置；测试前按手册准备。串口被其他进程占用时会拒绝运行，避免影响业务程序。正常退出时恢复原串口参数和RS485内核配置。
- 默认日志目录 `/mnt/sdcard` 必须已经挂载。其他日志目录可用 `--output-dir` 指定。

## 结果与调度

只有完成全部规定次数、没有读写/校验/序号/反馈错误且结果保存成功时，工具才返回0。工具返回1表示测试不通过，2表示配置/操作错误，130表示中断。调度器返回0表示全部已启用任务通过，1表示失败/超时，2表示调度或配置错误，信号取消返回`128+信号编号`。

每次运行创建唯一的 `all_test_XXXXXX` 目录，包含：

- `summary.log`：整轮结束、超时或取消后生成的最终结果汇总，只包含总结果、各任务状态、退出码、最终收发/错误统计和各IO通道结果。不记录中间进度、逐包OK、收发过程或执行命令。
- `summary.json`：便于程序读取的总体状态、各任务状态、退出码、实际命令、超时、工具文件指纹。
- `config.used.json`：原始配置快照；命令行覆盖后的生效值见汇总中的任务命令。
- 各任务子目录：`console.log` 和详细CSV/统计文件。

例如本次目录为 `/mnt/sdcard/all_test_ABC123`，只需打开或拷贝其中的 `summary.log` 即可查看整轮结果：

```sh
cat /mnt/sdcard/all_test_ABC123/summary.log
```

过程输出保留在各任务的 `console.log` 中，逐条采样CSV也保留在任务子目录；它们不会混入最终汇总。

对于已拷回电脑的多台设备或多轮结果，源码目录提供 `merge_result_logs.py`（Python 3.9及以上），可离线生成一个汇总文件，保留原日志：

```sh
python merge_result_logs.py /path/to/collected_results
```

输出为该目录的 `summary.log`。旧版只有工具日志、没有 `summary.json` 的记录会标为整体结果 `UNKNOWN`，不会仅凭日志中的零错误推断整轮通过。此脚本无需部署到设备。

状态包括 `PASS`、`FAIL`、`SKIPPED`、`TIMEOUT`、`ABORTED`、`CANCELLED`、`ERROR`；跳过与取消不会伪装成通过。失败默认不阻止其他已配置任务继续检测；`--fail-fast` 在发现失败后终止其他任务。默认按次数和间隔估算各项超时，总超时保守取各项超时之和。可用 `--timeout SECONDS` 设置总时限，或通过网口/串口类别、每对的 `timeout_seconds`、`dio.dido_timeout_seconds`、`dio.relay_timeout_seconds` 设置任务时限。

中断、超时或日志写入失败时，调度器会终止整个子进程组，最多等待3秒后强制结束并回收；同时拒绝第二个全量任务运行。GPIO工具正常取消时将输出拉低；强制断电或SIGKILL无法保证执行用户态清理，应检查实际输出状态。

通信包增加了每对、每方向的随机会话标记，可识别并行回路之间错接或旧数据混入，保持包长260/1400字节。新旧工具版本的包格式不兼容，请将整套工具一起更新。RS485的CRC错误统计表示重同步过程中发现的连续坏帧区域数，不等同于逐字节错误数；只有完整正确收包才会通过。

## 编译与验证

Linux本机编译需C++17编译器、make及libgpiod 1.x开发包：

```sh
make -j4
python3 tests/regression.py "$(pwd)/build"
```

回归测试还需Python3、C编译器，并以root运行调度器测试；使用模拟GPIO和Linux伪终端，不操作真实GPIO。生成的配置和日志位于临时目录，测试完成后自动删除。

ARM交叉编译：

```sh
sh build_arm_all.sh
```

默认使用 `arm-linux-gnueabihf-` 工具链，输出至 `build-arm/`，四个可执行文件静态链接。脚本会用同一工具链重编libgpiod，避免旧预编译库的glibc符号不兼容。可通过 `BUILD_DIR`、`CROSS_COMPILE` 和 `JOBS` 环境变量调整构建。
