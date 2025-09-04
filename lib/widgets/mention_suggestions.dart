import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/group_service.dart';
import '../widgets/common/network_avatar.dart';
import '../utils/logger.dart';

/// Widget to display mention suggestions when user types @
/// Based on Android source analysis from chat-mentions.md
class MentionSuggestions extends StatefulWidget {
  final String groupId;
  final String query;
  final Function(GroupMemberEntity member) onMemberSelected;
  final double maxHeight;

  const MentionSuggestions({
    Key? key,
    required this.groupId,
    required this.query,
    required this.onMemberSelected,
    this.maxHeight = 200,
  }) : super(key: key);

  @override
  State<MentionSuggestions> createState() => _MentionSuggestionsState();
}

class _MentionSuggestionsState extends State<MentionSuggestions> {
  List<GroupMemberEntity> _members = [];
  bool _loading = false;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void didUpdateWidget(MentionSuggestions oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Reload if query or groupId changed
    if (widget.query != _lastQuery || widget.groupId != oldWidget.groupId) {
      _loadMembers();
    }
  }

  Future<void> _loadMembers() async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _lastQuery = widget.query;
    });

    try {
      Logger.service(
        'MentionSuggestions',
        'Loading members for query: "${widget.query}"',
      );

      final members = await GroupService().getGroupMembers(
        widget.groupId,
        keyword: widget.query,
        limit: 20, // Limit suggestions to avoid too many results
      );

      if (mounted) {
        setState(() {
          _members = members;
          _loading = false;
        });

        Logger.service(
          'MentionSuggestions',
          'Loaded ${members.length} members',
        );
      }
    } catch (e) {
      Logger.error('MentionSuggestions: Failed to load members', error: e);
      if (mounted) {
        setState(() {
          _members = [];
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        height: 60,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_members.isEmpty) {
      return Container(
        height: 60,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'No members found',
            style: GoogleFonts.notoSansSc(
              color: const Color(0xFF6B7280),
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return Container(
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _members.length,
        itemBuilder: (context, index) {
          final member = _members[index];
          return _buildMemberTile(member);
        },
      ),
    );
  }

  Widget _buildMemberTile(GroupMemberEntity member) {
    // Determine display name (prioritize remark over name)
    final displayName = (member.remark?.isNotEmpty == true)
        ? member.remark!
        : (member.name?.isNotEmpty == true ? member.name! : member.uid);

    return InkWell(
      onTap: () => widget.onMemberSelected(member),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Avatar
            NetworkAvatar(
              imageUrl: member.avatar ?? '',
              displayName: displayName,
              size: 36,
            ),
            const SizedBox(width: 12),

            // Member info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Display name
                  Text(
                    displayName,
                    style: GoogleFonts.notoSansSc(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF374151),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Username/UID if different from display name
                  if (member.name != null &&
                      member.name!.isNotEmpty &&
                      member.name != displayName)
                    Text(
                      '@${member.name}',
                      style: GoogleFonts.notoSansSc(
                        fontSize: 14,
                        color: const Color(0xFF6B7280),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),

            // Role indicator (if admin/owner)
            if (member.role > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: member.role == 2
                      ? const Color(0xFFEF4444).withOpacity(0.1)
                      : const Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  member.role == 2 ? 'Owner' : 'Admin',
                  style: GoogleFonts.notoSansSc(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: member.role == 2
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF3B82F6),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
