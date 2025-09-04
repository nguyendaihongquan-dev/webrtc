// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'QGIM';

  @override
  String get settings_title => '设置';

  @override
  String get language_title => '语言';

  @override
  String get language_english => '英文';

  @override
  String get language_chinese => '中文';

  @override
  String get text_size => '字体大小';

  @override
  String get about => '关于';

  @override
  String get clear_images_cache => '清除图片缓存';

  @override
  String get cache_size_calculating => '计算中...';

  @override
  String get sign_out => '退出登录';

  @override
  String get coming_soon => '即将推出';

  @override
  String get me_title => '我';

  @override
  String get me_user_placeholder => '用户';

  @override
  String get me_computer_login => '电脑登录';

  @override
  String get me_notifications => '新消息通知';

  @override
  String get me_setting => '设置';

  @override
  String get login_auth_title => '登录认证';

  @override
  String get device_verification_required => '设备验证要求';

  @override
  String get device_verification_description =>
      '为了您的账户安全，QGIM需要验证此设备。我们将向您注册的手机号码发送验证码。';

  @override
  String get phone_number => '手机号码';

  @override
  String get send_verification_code => '发送验证码';

  @override
  String get verification_help_text => '如果您没有收到验证码，请检查您的手机号码或联系客服。';

  @override
  String get cancel => '取消';

  @override
  String get enter_verification_code => '输入验证码';

  @override
  String verification_code_sent_to(String phone) => '输入发送到 $phone 的验证码';

  @override
  String get verification_code_hint => '------';

  @override
  String get please_enter_verification_code => '请输入验证码';

  @override
  String get please_enter_complete_code => '请输入完整的验证码';

  @override
  String get verify => '验证';

  @override
  String get resend_code => '重新发送验证码';

  @override
  String get error => '错误';

  @override
  String get ok => '确定';

  @override
  String get notice => '通知';

  @override
  String get retry => '重试';

  @override
  String get new_chat => '新聊天';

  @override
  String get no_conversations_yet => '还没有对话';

  @override
  String get start_new_conversation => '开始新的对话';

  @override
  String get oops_something_went_wrong => '哎呀！出错了';

  @override
  String get loading_contacts => '正在加载联系人...';

  @override
  String get contacts => '联系人';

  @override
  String get copy => '复制';

  @override
  String get forward => '转发';

  @override
  String get delete => '删除';

  @override
  String get delete_message => '删除消息';

  @override
  String get delete_message_confirm => '您确定要删除这条消息吗？';

  @override
  String get delete_for_everyone_group => '为群组中的所有人删除';

  @override
  String get delete_for_both_sides => '为双方删除';

  @override
  String get deleted_for_everyone => '已为所有人删除';

  @override
  String get delete_failed => '删除失败';

  @override
  String failed_to_send_message(String error) => '发送消息失败：$error';

  @override
  String get cannot_forward_message => '无法转发此消息';

  @override
  String get cannot_forward_image => '无法转发此图片';

  @override
  String get image_forwarded_successfully => '图片转发成功';

  @override
  String get account_logged_another_device => '您的账户已在另一台设备上登录';

  @override
  String get account_banned => '您的账户已被封禁';

  @override
  String get official => '官方';

  @override
  String get bot => '机器人';

  @override
  String login_to_app(String appName) => '登录到 $appName';

  @override
  String get phone_number_label => '手机号码';

  @override
  String get password_label => '密码';

  @override
  String get agree_terms => '我同意服务条款和隐私政策';

  @override
  String get login_button => '登录';

  @override
  String get register_button => '注册';

  @override
  String get forgot_password => '忘记密码？';

  @override
  String get api_settings => 'API设置';
}
