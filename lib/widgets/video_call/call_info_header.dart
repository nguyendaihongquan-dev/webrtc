import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/video_call_model.dart';

/// Widget hiển thị thông tin cuộc gọi ở đầu màn hình
class CallInfoHeader extends StatelessWidget {
  final VideoCallModel? call;
  final bool isIncoming;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  const CallInfoHeader({
    Key? key,
    this.call,
    this.isIncoming = false,
    this.onAccept,
    this.onReject,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(0.7), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),

          const SizedBox(width: 8),

          // Call info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  call?.callerName ?? 'Unknown',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getCallStatusText(),
                  style: TextStyle(color: Colors.white70, fontSize: 14.sp),
                ),
              ],
            ),
          ),

          // Call type indicator
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  call?.callType == VideoCallType.group
                      ? Icons.group
                      : Icons.person,
                  color: Colors.white,
                  size: 16.sp,
                ),
                const SizedBox(width: 4),
                Text(
                  call?.callType == VideoCallType.group ? 'Nhóm' : '1-1',
                  style: TextStyle(color: Colors.white, fontSize: 12.sp),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getCallStatusText() {
    if (call == null) return '';

    switch (call!.callState) {
      case VideoCallState.calling:
        return isIncoming ? 'Cuộc gọi đến' : 'Đang gọi...';
      case VideoCallState.ringing:
        return 'Đang đổ chuông...';
      case VideoCallState.connecting:
        return 'Đang kết nối...';
      case VideoCallState.connected:
        return 'Đã kết nối';
      case VideoCallState.ended:
        return 'Cuộc gọi kết thúc';
      case VideoCallState.rejected:
        return 'Cuộc gọi bị từ chối';
      case VideoCallState.missed:
        return 'Cuộc gọi nhỡ';
      case VideoCallState.failed:
        return 'Cuộc gọi thất bại';
      default:
        return '';
    }
  }
}
