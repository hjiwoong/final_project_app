enum SignupTermType {
  cookie(
    'COOKIE',
    '쿠키 사용',
    '2026-11-18',
    '''서비스는 로그인 상태 유지와 이용 환경 개선을 위해 쿠키 및 유사 기술을 사용할 수 있습니다.

쿠키는 서비스 이용 과정에서 필요한 정보를 저장하는 작은 데이터입니다. 이용자는 브라우저 또는 기기의 설정을 통해 쿠키 저장을 제한할 수 있으며, 이 경우 일부 기능 이용이 제한될 수 있습니다.''',
  ),
  termsOfService(
    'TERMS',
    '이용약관',
    '2026-11-18',
    '''본 약관은 서비스 이용에 필요한 기본 사항과 회원 및 서비스 운영자의 권리와 의무를 정합니다.

회원은 관계 법령과 본 약관을 준수하여 서비스를 이용해야 합니다. 다른 회원의 권리를 침해하거나 서비스 운영을 방해하는 행위는 제한될 수 있습니다.

운영자는 안정적인 서비스 제공을 위해 노력하며, 서비스 내용이나 약관을 변경하는 경우 서비스 내 공지 등 적절한 방법으로 안내합니다.''',
  ),
  privacyPolicy(
    'PRIVACY',
    '개인정보 처리방침',
    '2026-11-18',
    '''서비스는 회원가입과 서비스 제공에 필요한 개인정보를 최소한으로 수집하고 목적에 필요한 범위에서 이용합니다.

회원은 이메일 주소와 이름을 제공하며, 개인정보는 회원 식별, 계정 관리 및 서비스 제공을 위해 이용됩니다. 개인정보는 이용 목적이 달성되거나 보유 기간이 끝나면 관계 법령에 따라 안전하게 파기합니다.

회원은 개인정보 열람, 정정 및 삭제를 요청할 수 있습니다. 서비스는 개인정보를 안전하게 관리하기 위해 필요한 보호 조치를 적용합니다.''',
  );

  const SignupTermType(this.apiValue, this.title, this.version, this.body);

  final String apiValue;
  final String title;
  final String version;
  final String body;

  static SignupTermType fromApiValue(String value) => values.firstWhere(
    (type) =>
        type.apiValue == value ||
        switch ((type, value)) {
          (SignupTermType.termsOfService, 'TERMS_OF_SERVICE') => true,
          (SignupTermType.privacyPolicy, 'PRIVACY_POLICY') => true,
          _ => false,
        },
    orElse: () => throw FormatException('지원하지 않는 약관 유형입니다: $value'),
  );
}

class SignupTermInfo {
  const SignupTermInfo({
    required this.type,
    required this.title,
    required this.version,
    this.required = true,
    this.apiType,
  });

  final SignupTermType type;
  final String title;
  final String version;
  final bool required;
  final String? apiType;

  factory SignupTermInfo.fromJson(Map<String, dynamic> json) {
    final apiType = json['type'] as String;
    final type = SignupTermType.fromApiValue(apiType);
    final title = json['title'] as String;
    final version = json['version'] as String;
    if (title.isEmpty || version.isEmpty) {
      throw const FormatException('약관 제목 또는 버전이 비어 있습니다.');
    }
    final required = json['required'];
    if (required != null && required is! bool) {
      throw const FormatException('약관 필수 여부가 올바르지 않습니다.');
    }
    return SignupTermInfo(
      type: type,
      title: title,
      version: version,
      required: required as bool? ?? true,
      apiType: apiType,
    );
  }
}

class SignupTermAgreement {
  const SignupTermAgreement({
    required this.type,
    required this.version,
    this.apiType,
  });

  final SignupTermType type;
  final String version;
  final String? apiType;

  Map<String, String> toJson() => {
    'term_type': apiType ?? type.apiValue,
    'term_version': version,
  };

  factory SignupTermAgreement.fromJson(Map<String, dynamic> json) {
    final apiType = json['term_type'] as String;
    final version = json['term_version'] as String;
    if (version.isEmpty) {
      throw const FormatException('약관 버전이 비어 있습니다.');
    }
    return SignupTermAgreement(
      type: SignupTermType.fromApiValue(apiType),
      version: version,
      apiType: apiType,
    );
  }
}
