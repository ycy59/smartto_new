import 'package:flutter/material.dart';

class CameraPage extends StatefulWidget {
  final String selectedTask;

  const CameraPage({
    super.key,
    required this.selectedTask,
  });

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  bool isCompleted = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 8),

              // 상단
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Camera-go',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF8A8A8A),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.circle,
                              size: 8,
                              color: Color(0xFFD95C4F),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.selectedTask,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF232323),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: () {
                            setState(() {
                                isCompleted = !isCompleted;
                            });
                        },
                        child: Text(
                            isCompleted ? '미완료' : '완료',
                            style: TextStyle(
                                color: isCompleted
                                    ? const Color(0xFF7A7A7A)
                                    : const Color(0xFF232323),
                                fontWeight: FontWeight.w600,
                            ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: const Text('카메라'),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 24),

              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 왼쪽 할 일 목록
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF5FB),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '오늘 할 일',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _buildTask('알고리즘 - Chapter1 복습'),
                            _buildTask('알고리즘 - 비정렬법 구현'),
                            _buildTask('운영체제 - 3장 읽기'),
                            _buildTask('인터넷 프로그래밍 - 16주차'),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 20),

                    // 가운데 타이머
                    Expanded(
                      flex: 3,
                      child: Center(
                        child: Container(
                          width: 190,
                          height: 190,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFB14537),
                              width: 6,
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              '20:38',
                              style: TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 20),

                    // 오른쪽 카메라 자리
                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.bottomRight,
                        child: Container(
                          height: 180,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDEDED),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.person_outline,
                              size: 42,
                              color: Color(0xFFC7C7C7),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 하단 버튼
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    isCompleted = !isCompleted;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(18),
                ),
                child: Icon(
                  isCompleted ? Icons.refresh : Icons.check,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTask(String title) {
    final bool done = isCompleted && widget.selectedTask == title;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            Icons.circle,
            size: 8,
            color: done
                ? const Color(0xFFCBCBCB)
                : const Color(0xFFD95C4F),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                color: done
                    ? const Color(0xFFCBCBCB)
                    : const Color(0xFF232323),
              ),
            ),
          ),
          if (done)
            const Icon(
              Icons.check_circle,
              size: 16,
              color: Color(0xFF7ACB6A),
            ),
        ],
      ),
    );
  }
}