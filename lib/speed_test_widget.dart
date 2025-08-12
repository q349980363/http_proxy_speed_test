import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:dio/dio.dart';

// 速度数据点类，用于平滑处理
class SpeedDataPoint {
  final DateTime timestamp;
  final double speed; // MB/s

  SpeedDataPoint(this.timestamp, this.speed);
}

class SpeedTestWidget extends StatefulWidget {
  const SpeedTestWidget({super.key});

  @override
  State<SpeedTestWidget> createState() => _SpeedTestWidgetState();
}

class _SpeedTestWidgetState extends State<SpeedTestWidget> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _proxyHostController = TextEditingController();
  final TextEditingController _proxyPortController = TextEditingController();
  final TextEditingController _proxyUsernameController =
      TextEditingController();
  final TextEditingController _proxyPasswordController =
      TextEditingController();
  bool _isDownloading = false;
  bool _useProxy = false;
  double _currentSpeed = 0.0; // MB/s
  double _totalDownloaded = 0.0; // MB
  double _averageSpeed = 0.0; // MB/s
  double _maxSpeed = 0.0; // MB/s
  String _speedUnit = 'MB/s';
  Timer? _speedTimer;
  Dio? _dio;
  CancelToken? _cancelToken;
  int _totalDownloadedBytes = 0; // 总下载字节数
  // 折线图数据
  final List<FlSpot> _speedData = [];
  final double _chartMaxX = 120; // 显示最近600个数据点
  int _dataPointIndex = 0;
  // 速度统计
  final List<double> _speedHistory = [];
  // 平滑处理 - 保存最近5秒的速度数据
  final List<SpeedDataPoint> _recentSpeedData = [];
  static const int _smoothingWindowSeconds = 5;

  @override
  void initState() {
    super.initState();
    _urlController.text =
        'https://speed.cloudflare.com/__down?during=download&bytes=1073741824'; // 默认测试URL
  }

  @override
  void dispose() {
    _urlController.dispose();
    _proxyHostController.dispose();
    _proxyPortController.dispose();
    _proxyUsernameController.dispose();
    _proxyPasswordController.dispose();
    _stopSpeedTest();
    super.dispose();
  }

  void _startSpeedTest() async {
    if (_urlController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入URL')));
      return;
    }
    setState(() {
      _isDownloading = true;
      _currentSpeed = 0.0;
      _totalDownloaded = 0.0;
      _totalDownloadedBytes = 0;
      _averageSpeed = 0.0;
      _maxSpeed = 0.0;
      _speedData.clear();
      _speedHistory.clear();
      _recentSpeedData.clear();
      _dataPointIndex = 0;
    });
    try {
      // 创建Dio实例并配置代理
      _dio = Dio();
      _cancelToken = CancelToken();

      if (_useProxy && _proxyHostController.text.isNotEmpty) {
        final proxyUrl =
            'http://${_proxyHostController.text}:${_proxyPortController.text}';
        _dio!.options.extra['proxy'] = proxyUrl;

        // 如果有用户名和密码，设置认证
        if (_proxyUsernameController.text.isNotEmpty) {
          final auth =
              '${_proxyUsernameController.text}:${_proxyPasswordController.text}';
          _dio!.options.headers['Proxy-Authorization'] =
              'Basic ${base64Encode(utf8.encode(auth))}';
        }
      }

      int downloadedBytes = 0;
      final startTime = DateTime.now();
      DateTime lastUpdateTime = startTime;

      // 启动速度计算定时器
      _speedTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
        final currentTime = DateTime.now();
        final timeDiff = currentTime.difference(lastUpdateTime).inMilliseconds;

        if (timeDiff > 0) {
          final speedBytesPerSecond = (downloadedBytes * 1000) / timeDiff;
          _updateSpeed(speedBytesPerSecond, _totalDownloadedBytes.toDouble());
          lastUpdateTime = currentTime;
          downloadedBytes = 0; // 重置计数器
        }
      });

      // 使用Dio下载
      // await _dio!.download(
      //   _urlController.text,
      //   "null", // 不保存到文件，只是测速
      //   cancelToken: _cancelToken,
      //   onReceiveProgress: (received, total) {
      //     if (_isDownloading) {
      //       final newBytes = received - _totalDownloadedBytes;
      //       downloadedBytes += newBytes;
      //       _totalDownloadedBytes = received;
      //     }
      //   },
      // );

      Response response = await _dio!.get(
        _urlController.text,
        cancelToken: _cancelToken,
        options: Options(responseType: ResponseType.stream),
        onReceiveProgress: (received, total) {
          if (_isDownloading) {
            final newBytes = received - _totalDownloadedBytes;
            downloadedBytes += newBytes;
            _totalDownloadedBytes = received;
          }
        },
      );

      // 正确处理 ResponseBody 流
      ResponseBody responseBody = response.data;
      await for (List<int> chunk in responseBody.stream) {
        // 消费数据但不保存
        if (_cancelToken?.isCancelled == true) {
          break;
        }
      }

      _stopSpeedTest();
    } catch (e) {
      _stopSpeedTest();
      // 打印错误信息
      print('连接错误: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('连接错误: $e')));
    }
  }

  void _stopSpeedTest() {
    setState(() {
      _isDownloading = false;
    });

    _speedTimer?.cancel();
    _speedTimer = null;

    _cancelToken?.cancel();
    _cancelToken = null;

    _dio?.close();
    _dio = null;
  }

  void _updateSpeed(double bytesPerSecond, double totalBytes) {
    if (!mounted) return;

    final currentTime = DateTime.now();
    double speedInMBps = bytesPerSecond / (1024 * 1024); // 直接转换为MB/s

    // 添加当前速度数据点
    _recentSpeedData.add(SpeedDataPoint(currentTime, speedInMBps));

    // 移除超过5秒的旧数据
    _recentSpeedData.removeWhere(
      (dataPoint) =>
          currentTime.difference(dataPoint.timestamp).inSeconds >
          _smoothingWindowSeconds,
    );

    // 计算平滑后的速度（5秒内的平均值）
    double smoothedSpeed = speedInMBps;
    if (_recentSpeedData.isNotEmpty) {
      smoothedSpeed =
          _recentSpeedData.map((dp) => dp.speed).reduce((a, b) => a + b) /
          _recentSpeedData.length;
    }

    setState(() {
      _totalDownloaded = totalBytes / (1024 * 1024); // 转换为MB

      _speedHistory.add(smoothedSpeed);

      // 更新最大速度（使用原始速度，不是平滑后的）
      if (speedInMBps > _maxSpeed) {
        _maxSpeed = speedInMBps;
      }

      // 计算平均速度
      if (_speedHistory.isNotEmpty) {
        _averageSpeed =
            _speedHistory.reduce((a, b) => a + b) / _speedHistory.length;
      }

      // 添加图表数据点（使用平滑后的速度）
      _speedData.add(FlSpot(_dataPointIndex.toDouble(), smoothedSpeed));
      _dataPointIndex++;

      // 保持图表数据点数量在合理范围内
      if (_speedData.length > _chartMaxX) {
        _speedData.removeAt(0);
        // 重新调整x轴坐标
        for (int i = 0; i < _speedData.length; i++) {
          _speedData[i] = FlSpot(i.toDouble(), _speedData[i].y);
        }
        _dataPointIndex = _speedData.length;
      }

      // 显示平滑后的当前速度（统一使用MB/s）
      _currentSpeed = smoothedSpeed;
      _speedUnit = 'MB/s';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // URL输入框
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: '测试URL',
                hintText: '请输入要测试的下载链接',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
              enabled: !_isDownloading,
            ),

            const SizedBox(height: 16),

            // 代理设置
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: _useProxy,
                          onChanged: _isDownloading
                              ? null
                              : (value) {
                                  setState(() {
                                    _useProxy = value ?? false;
                                  });
                                },
                        ),
                        const Text('使用HTTP代理', style: TextStyle(fontSize: 16)),
                      ],
                    ),
                    if (_useProxy) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: _proxyHostController,
                              decoration: const InputDecoration(
                                labelText: '代理服务器',
                                hintText: '例: 127.0.0.1',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              enabled: !_isDownloading,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 1,
                            child: TextField(
                              controller: _proxyPortController,
                              decoration: const InputDecoration(
                                labelText: '端口',
                                hintText: '8080',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              enabled: !_isDownloading,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _proxyUsernameController,
                              decoration: const InputDecoration(
                                labelText: '用户名（可选）',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              enabled: !_isDownloading,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _proxyPasswordController,
                              decoration: const InputDecoration(
                                labelText: '密码（可选）',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              enabled: !_isDownloading,
                              obscureText: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 开始/停止按钮
            ElevatedButton(
              onPressed: _isDownloading ? _stopSpeedTest : _startSpeedTest,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isDownloading ? Colors.red : Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                _isDownloading ? '停止测速' : '开始测速',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 速度统计卡片
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // 实时速度
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _isDownloading
                            ? const SizedBox(
                                width: 32,
                                height: 32,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.blue,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.speed,
                                size: 32,
                                color: Colors.blue,
                              ),
                        const SizedBox(width: 12),
                        Text(
                          '${_currentSpeed.toStringAsFixed(2)} $_speedUnit',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // 速度统计
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text(
                              '平均速度',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '${_averageSpeed.toStringAsFixed(1)} MB/s',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            const Text(
                              '最大速度',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '${_maxSpeed.toStringAsFixed(1)} MB/s',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            const Text(
                              '已下载',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '${_totalDownloaded.toStringAsFixed(1)} MB',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // 状态指示器
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _isDownloading ? Colors.green : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isDownloading ? '正在测速...' : '待机中',
                          style: TextStyle(
                            color: _isDownloading ? Colors.green : Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 实时速度折线图
            if (_speedData.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '实时下载速率图表',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 300,
                        child: LineChart(
                          LineChartData(
                            gridData: FlGridData(show: true),
                            titlesData: FlTitlesData(
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 120,
                                  interval: 5,
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      '${value.toInt()}s',
                                      style: const TextStyle(fontSize: 10),
                                    );
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 60,
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      '${value.toStringAsFixed(1)}MB/s',
                                      style: const TextStyle(fontSize: 10),
                                    );
                                  },
                                ),
                              ),
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                            ),
                            borderData: FlBorderData(show: true),
                            minX: 0,
                            maxX: max(_chartMaxX, _speedData.length.toDouble()),
                            minY: 0,
                            maxY: _maxSpeed > 0
                                ? _maxSpeed * 1.1
                                : 10, // 调整默认最大值为10MB/s
                            lineBarsData: [
                              LineChartBarData(
                                spots: _speedData,
                                isCurved: true,
                                color: Colors.blue,
                                barWidth: 2,
                                dotData: const FlDotData(show: false),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: Colors.blue.withOpacity(0.1),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
