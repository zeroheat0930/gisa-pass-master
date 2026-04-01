import 'package:flutter/material.dart';
import '../config.dart';

class CheatSheetScreen extends StatefulWidget {
  const CheatSheetScreen({super.key});

  @override
  State<CheatSheetScreen> createState() => _CheatSheetScreenState();
}

class _CheatSheetScreenState extends State<CheatSheetScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sections = _buildSections();
    final filtered = _searchQuery.isEmpty
        ? sections
        : sections
            .where((s) =>
                s.title.contains(_searchQuery) ||
                s.content.any((item) =>
                    item.term.contains(_searchQuery) ||
                    item.definition.contains(_searchQuery)))
            .toList();

    return Scaffold(
      backgroundColor: AppConfig.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppConfig.surfaceColor,
        title: const Text(
          '족보 핵심정리',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: '용어 검색...',
                hintStyle: TextStyle(color: Colors.white.withAlpha(128)),
                prefixIcon:
                    Icon(Icons.search, color: Colors.white.withAlpha(179)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppConfig.cardColor,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
        ),
      ),
      body: filtered.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off,
                      size: 48, color: Colors.white.withAlpha(77)),
                  const SizedBox(height: 12),
                  Text(
                    '"$_searchQuery" 검색 결과 없음',
                    style: TextStyle(color: Colors.white.withAlpha(128)),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: filtered.length,
              itemBuilder: (context, index) =>
                  _SectionCard(section: filtered[index]),
            ),
    );
  }

  List<_Section> _buildSections() {
    return [
      // ─── 1. 소프트웨어 개발 방법론 ────────────────────────────────────
      _Section(
        title: '소프트웨어 개발 방법론',
        icon: Icons.build,
        iconColor: const Color(0xFFFF7043),
        content: [
          _Item.red('폭포수(Waterfall)', '요구→설계→구현→시험→유지보수 순서, 단계 역행 불가, 문서 중심'),
          _Item.def('나선형(Spiral)', '위험분석 반복, Boehm 제안, 프로토타입+폭포수 결합'),
          _Item.blue('애자일(Agile)', '짧은 이터레이션, 변화 수용, 동작하는 소프트웨어 우선, 협업 강조'),
          _Item.red('스크럼(Scrum)',
              'Sprint(1~4주) 반복, Product Backlog→Sprint Backlog→Daily Scrum→Sprint Review'),
          _Item.def('XP(eXtreme Programming)', 'TDD·페어프로그래밍·지속통합·리팩토링·코드공유, 12가지 실천법'),
          _Item.blue('칸반(Kanban)', 'WIP 제한, 시각적 보드(할일→진행→완료), 흐름 최적화'),
          _Item.def('DevOps', '개발+운영 통합, 자동화 파이프라인, 빠른 배포 사이클'),
          _Item.blue('CI/CD',
              'CI=지속통합(코드병합+자동빌드+테스트), CD=지속배포(자동 스테이징/프로덕션 배포)'),
        ],
      ),

      // ─── 2. UML 다이어그램 ────────────────────────────────────────────
      _Section(
        title: 'UML 다이어그램',
        icon: Icons.account_tree,
        iconColor: const Color(0xFF42A5F5),
        content: [
          _Item.header('── 구조 다이어그램 (Structure) ──'),
          _Item.blue('클래스(Class)', '클래스·속성·메서드·관계 표현, 가장 많이 사용'),
          _Item.def('객체(Object)', '클래스 인스턴스 스냅샷, 특정 시점의 상태'),
          _Item.def('컴포넌트(Component)', '소프트웨어 컴포넌트 간 의존성·인터페이스'),
          _Item.def('배치(Deployment)', '하드웨어·소프트웨어 물리적 배치 구조'),
          _Item.def('패키지(Package)', '클래스 그룹화, 네임스페이스 구조'),
          _Item.def('복합구조(Composite)', '클래스 내부 구조와 협력 관계'),
          _Item.header('── 행위 다이어그램 (Behavior) ──'),
          _Item.red('유스케이스(Use Case)', '시스템 기능(유스케이스)과 액터 간 관계'),
          _Item.red('시퀀스(Sequence)', '객체 간 메시지 교환 순서, 시간 흐름 표현'),
          _Item.blue('활동(Activity)', '업무 흐름·알고리즘, 병렬 처리 표현'),
          _Item.def('상태(State)', '객체 상태 변화와 이벤트/전이'),
          _Item.def('통신(Communication)', '시퀀스와 유사, 링크 관계 중심'),
          _Item.def('타이밍(Timing)', '상태변화 시간 제약 표현'),
          _Item.header('── 관계 종류 ──'),
          _Item.red('연관(Association)', '클래스 간 일반 관계, 실선'),
          _Item.def('의존(Dependency)', '한 클래스가 다른 클래스 사용, 점선 화살표'),
          _Item.blue('일반화(Generalization)', '상속관계, 실선+빈 삼각형 화살표 (부모 방향)'),
          _Item.def('실체화(Realization)', '인터페이스 구현, 점선+빈 삼각형'),
          _Item.def('집합(Aggregation)', '전체-부분 관계, 부분 독립 존재 가능, 빈 마름모'),
          _Item.red('합성(Composition)', '강한 전체-부분, 부분 독립 불가, 채운 마름모'),
        ],
      ),

      // ─── 3. 디자인 패턴 ───────────────────────────────────────────────
      _Section(
        title: '디자인 패턴 (GoF 23)',
        icon: Icons.pattern,
        iconColor: const Color(0xFFAB47BC),
        content: [
          _Item.header('── 생성 패턴 (Creational) ──'),
          _Item.red('Singleton', '인스턴스 1개만 생성, 전역 접근점 제공'),
          _Item.blue('Factory Method', '객체 생성을 서브클래스가 결정, 인터페이스로 생성 위임'),
          _Item.def('Abstract Factory', '관련 객체군을 인터페이스로 묶어 생성'),
          _Item.def('Builder', '복잡한 객체를 단계별 생성, 생성-표현 분리'),
          _Item.def('Prototype', '기존 객체 복제(clone)로 새 객체 생성'),
          _Item.header('── 구조 패턴 (Structural) ──'),
          _Item.blue('Adapter', '호환되지 않는 인터페이스를 변환(래퍼), 기존 클래스 재사용'),
          _Item.def('Bridge', '추상과 구현을 분리해 독립적으로 확장'),
          _Item.def('Composite', '트리 구조, 개별·복합 객체 동일하게 처리'),
          _Item.blue('Decorator', '객체에 동적으로 기능 추가, 상속 대안'),
          _Item.def('Facade', '복잡한 서브시스템에 단순 인터페이스 제공'),
          _Item.red('Proxy', '객체 접근 제어, 원격/가상/보호 프록시'),
          _Item.header('── 행위 패턴 (Behavioral) ──'),
          _Item.red('Observer', '1:N 의존, 상태 변화 시 자동 알림 (이벤트 리스너)'),
          _Item.blue('Strategy', '알고리즘 캡슐화, 런타임에 교체 가능'),
          _Item.def('Template Method', '알고리즘 골격 정의, 세부 단계는 서브클래스가 구현'),
          _Item.def('Command', '요청을 객체로 캡슐화, 실행취소·큐잉 가능'),
          _Item.def('State', '객체 상태에 따라 행동 변경, if-else 대체'),
          _Item.def('Iterator', '컬렉션 내부 구조 노출 없이 순차 접근'),
        ],
      ),

      // ─── 4. 테스트 기법 ───────────────────────────────────────────────
      _Section(
        title: '테스트 기법',
        icon: Icons.bug_report,
        iconColor: const Color(0xFF66BB6A),
        content: [
          _Item.header('── 화이트박스 테스트 (구조 기반) ──'),
          _Item.red('문장 커버리지', '모든 실행 가능한 문장을 최소 1회 실행'),
          _Item.blue('분기(결정) 커버리지', '모든 분기(True/False)를 최소 1회 실행'),
          _Item.def('조건 커버리지', '각 조건식의 True/False를 최소 1회'),
          _Item.def('경로 커버리지', '모든 독립적 경로 실행 (가장 강력)'),
          _Item.header('── 블랙박스 테스트 (명세 기반) ──'),
          _Item.red('동치분할(Equivalence)', '입력 데이터를 동치 클래스로 분류, 대표값만 테스트'),
          _Item.blue('경계값 분석', '경계값(최솟값-1, 최솟값, 최솟값+1 등) 집중 테스트'),
          _Item.def('원인-결과 그래프', '원인(입력)과 결과(출력) 조합을 논리 그래프로 표현'),
          _Item.def('상태전이 테스트', '시스템 상태 변화와 이벤트 조합 테스트'),
          _Item.header('── 테스트 레벨 (V-모델) ──'),
          _Item.red('단위(Unit)', '모듈/함수 단위, 개발자 수행, 화이트박스'),
          _Item.blue('통합(Integration)', '모듈 간 인터페이스, 빅뱅/하향식/상향식/샌드위치'),
          _Item.def('시스템(System)', '전체 시스템, 기능+비기능 요구사항 검증'),
          _Item.def('인수(Acceptance)', '고객 검증, 알파(개발사)·베타(실사용자) 테스트'),
          _Item.header('── V-모델 대응 ──'),
          _Item.def('요구사항 분석 ↔ 인수테스트', '요구사항 명세 기반 인수 기준'),
          _Item.def('시스템 설계 ↔ 시스템테스트', '아키텍처 기반 통합 검증'),
          _Item.def('상세 설계 ↔ 통합테스트', '모듈 인터페이스 검증'),
          _Item.def('구현 ↔ 단위테스트', '코드 레벨 검증'),
        ],
      ),

      // ─── 5. OSI 7계층 ─────────────────────────────────────────────────
      _Section(
        title: 'OSI 7계층',
        icon: Icons.layers,
        iconColor: const Color(0xFF26C6DA),
        isTable: true,
        tableHeaders: const ['계층', '이름', '역할', '프로토콜/장비', 'PDU'],
        tableRows: const [
          ['7', '응용(Application)', 'HTTP·메일·파일 전송 등 서비스', 'HTTP,FTP,DNS,SMTP', '데이터'],
          ['6', '표현(Presentation)', '데이터 형식변환·암호화·압축', 'SSL,TLS,JPEG', '데이터'],
          ['5', '세션(Session)', '세션 설정·유지·종료', 'NetBIOS,RPC', '데이터'],
          ['4', '전송(Transport)', '종단간 신뢰성, 흐름/혼잡 제어', 'TCP,UDP', '세그먼트'],
          ['3', '네트워크(Network)', '논리적 주소(IP), 라우팅', 'IP,ICMP,ARP 라우터', '패킷'],
          ['2', '데이터링크(Data Link)', '물리 주소(MAC), 오류 검출', 'Ethernet,PPP 스위치', '프레임'],
          ['1', '물리(Physical)', '비트 전송, 전기 신호', '허브,리피터,케이블', '비트'],
        ],
        content: [],
      ),

      // ─── 6. TCP/IP & 프로토콜 ─────────────────────────────────────────
      _Section(
        title: 'TCP/IP & 프로토콜',
        icon: Icons.wifi,
        iconColor: const Color(0xFF29B6F6),
        content: [
          _Item.header('── TCP vs UDP ──'),
          _Item.red('TCP', '연결지향, 신뢰성, 순서보장, 흐름/혼잡제어, 느림 → HTTP·FTP·이메일'),
          _Item.blue('UDP', '비연결, 빠름, 순서보장X, 신뢰성X → DNS·스트리밍·게임·VoIP'),
          _Item.header('── 3-way Handshake (연결) ──'),
          _Item.def('SYN', '① 클라이언트 → 서버: SYN(연결 요청)'),
          _Item.def('SYN+ACK', '② 서버 → 클라이언트: SYN+ACK(승인)'),
          _Item.def('ACK', '③ 클라이언트 → 서버: ACK(확인) → 연결 수립'),
          _Item.header('── 4-way Handshake (해제) ──'),
          _Item.def('FIN', '① 클라이언트 → 서버: FIN'),
          _Item.def('ACK', '② 서버 → 클라이언트: ACK'),
          _Item.def('FIN', '③ 서버 → 클라이언트: FIN'),
          _Item.def('ACK', '④ 클라이언트 → 서버: ACK → 연결 종료'),
          _Item.header('── 주요 프로토콜 ──'),
          _Item.red('HTTP/HTTPS', 'HTTP=80(평문), HTTPS=443(TLS 암호화)'),
          _Item.def('FTP', '파일 전송, 21(제어), 20(데이터)'),
          _Item.def('DNS', '도메인→IP 변환, UDP 53 (TCP도 사용)'),
          _Item.def('DHCP', 'IP 자동 할당, UDP 67(서버)/68(클라이언트)'),
          _Item.blue('ARP', 'IP → MAC 주소 변환'),
          _Item.def('RARP', 'MAC → IP 주소 변환'),
          _Item.def('ICMP', '오류 보고·진단(ping), 네트워크 계층'),
          _Item.def('SMTP/POP3', 'SMTP=메일 송신(25), POP3=메일 수신(110)'),
          _Item.def('SNMP', '네트워크 장비 관리·모니터링, UDP 161'),
          _Item.header('── IP 클래스 ──'),
          _Item.def('Class A', '0.0.0.0 ~ 127.255.255.255, /8, 대형 네트워크'),
          _Item.def('Class B', '128.0.0.0 ~ 191.255.255.255, /16, 중형'),
          _Item.def('Class C', '192.0.0.0 ~ 223.255.255.255, /24, 소형'),
          _Item.def('Class D', '224.0.0.0 ~ 239.255.255.255, 멀티캐스트'),
          _Item.def('Class E', '240.0.0.0 ~ 255.255.255.255, 연구용 예약'),
          _Item.red('서브넷마스크', '/24 = 255.255.255.0, /16 = 255.255.0.0, /8 = 255.0.0.0'),
        ],
      ),

      // ─── 7. SQL 핵심 정리 ─────────────────────────────────────────────
      _Section(
        title: 'SQL 핵심 정리',
        icon: Icons.storage,
        iconColor: const Color(0xFFFFCA28),
        content: [
          _Item.header('── DDL (Data Definition Language) ──'),
          _Item.red('CREATE', 'CREATE TABLE t (id INT PRIMARY KEY, name VARCHAR(50))'),
          _Item.def('ALTER', 'ALTER TABLE t ADD col INT / MODIFY col / DROP COLUMN col'),
          _Item.def('DROP', 'DROP TABLE t → 테이블+데이터 완전 삭제, 롤백 불가'),
          _Item.blue('TRUNCATE', 'TRUNCATE TABLE t → 데이터만 삭제, 구조 유지, 빠름, 롤백 불가'),
          _Item.header('── DML (Data Manipulation Language) ──'),
          _Item.red('SELECT', 'SELECT col FROM t WHERE 조건 GROUP BY col HAVING 조건 ORDER BY col'),
          _Item.def('INSERT', "INSERT INTO t (col1,col2) VALUES (v1,v2)"),
          _Item.def('UPDATE', 'UPDATE t SET col=v WHERE 조건'),
          _Item.def('DELETE', 'DELETE FROM t WHERE 조건 → 롤백 가능'),
          _Item.header('── DCL (Data Control Language) ──'),
          _Item.def('GRANT', "GRANT SELECT,INSERT ON t TO user → 권한 부여"),
          _Item.def('REVOKE', "REVOKE SELECT ON t FROM user → 권한 회수"),
          _Item.red('COMMIT', '트랜잭션 확정, 영구 저장'),
          _Item.def('ROLLBACK', '트랜잭션 취소, 이전 상태로 복구'),
          _Item.header('── JOIN 종류 ──'),
          _Item.red('INNER JOIN', '두 테이블 교집합, 일치하는 행만'),
          _Item.blue('LEFT JOIN', '왼쪽 테이블 전체 + 오른쪽 일치 행'),
          _Item.def('RIGHT JOIN', '오른쪽 테이블 전체 + 왼쪽 일치 행'),
          _Item.def('FULL OUTER JOIN', '두 테이블 합집합, NULL 포함'),
          _Item.def('CROSS JOIN', '카테시안 곱(모든 조합), ON 조건 없음'),
          _Item.def('SELF JOIN', '같은 테이블 자기 자신과 JOIN'),
          _Item.header('── GROUP BY / HAVING / WHERE ──'),
          _Item.red('실행 순서', 'FROM → WHERE → GROUP BY → HAVING → SELECT → ORDER BY'),
          _Item.blue('WHERE vs HAVING', 'WHERE=그룹화 전 행 필터, HAVING=그룹화 후 집계 필터'),
          _Item.header('── 서브쿼리 종류 ──'),
          _Item.def('스칼라 서브쿼리', 'SELECT절에 위치, 단일 값 반환'),
          _Item.def('인라인 뷰', 'FROM절에 위치, 가상 테이블'),
          _Item.def('중첩 서브쿼리', 'WHERE절에 위치, IN/EXISTS/ANY/ALL'),
          _Item.header('── 윈도우 함수 ──'),
          _Item.red('ROW_NUMBER()', '중복 없이 순위 (1,2,3,4...)'),
          _Item.blue('RANK()', '동점 건너뜀 (1,2,2,4...)'),
          _Item.def('DENSE_RANK()', '동점 건너뛰지 않음 (1,2,2,3...)'),
          _Item.def('문법', 'FUNC() OVER (PARTITION BY col ORDER BY col)'),
        ],
      ),

      // ─── 8. 데이터베이스 ──────────────────────────────────────────────
      _Section(
        title: '데이터베이스 이론',
        icon: Icons.dns,
        iconColor: const Color(0xFFEC407A),
        content: [
          _Item.header('── 정규화 ──'),
          _Item.red('1NF', '원자값: 반복 그룹 제거, 각 셀은 단일 값'),
          _Item.red('2NF', '1NF + 부분함수 종속 제거 (기본키 전체에 종속)'),
          _Item.red('3NF', '2NF + 이행함수 종속 제거 (A→B→C 제거)'),
          _Item.blue('BCNF', '3NF + 모든 결정자가 후보키여야 함'),
          _Item.header('── 키(Key) 종류 ──'),
          _Item.red('기본키(Primary Key)', '유일식별, NULL 불가, 1개'),
          _Item.blue('후보키(Candidate Key)', '유일성+최소성 만족, 기본키 될 수 있는 키'),
          _Item.def('대체키(Alternate Key)', '후보키 중 기본키로 선택되지 않은 키'),
          _Item.def('외래키(Foreign Key)', '다른 테이블의 기본키 참조, NULL 가능'),
          _Item.def('슈퍼키(Super Key)', '유일성만 만족, 최소성 불필요'),
          _Item.header('── 트랜잭션 ACID ──'),
          _Item.red('원자성(Atomicity)', '전부 실행 or 전부 취소 (All or Nothing)'),
          _Item.blue('일관성(Consistency)', '트랜잭션 전후 DB 일관된 상태 유지'),
          _Item.def('격리성(Isolation)', '동시 트랜잭션 간 독립적 실행'),
          _Item.def('지속성(Durability)', '완료된 트랜잭션 결과 영구 저장'),
          _Item.header('── 이상현상 ──'),
          _Item.def('삽입 이상', '원하지 않는 데이터도 함께 삽입해야 하는 문제'),
          _Item.def('삭제 이상', '데이터 삭제 시 다른 필요한 데이터도 삭제됨'),
          _Item.def('갱신 이상', '중복 데이터 일부만 변경 시 불일치 발생'),
          _Item.header('── 동시성 제어 ──'),
          _Item.blue('로킹(Locking)', '자원 잠금, 공유락(읽기)/배타락(읽기+쓰기)'),
          _Item.def('2PL(2단계 로킹)', '확장단계(락 획득) → 수축단계(락 해제)'),
          _Item.def('타임스탬프', '트랜잭션별 시간 순서 부여, 직렬성 보장'),
          _Item.header('── 관계대수 ──'),
          _Item.red('σ (Selection/셀렉트)', '조건에 맞는 행 선택 (WHERE)'),
          _Item.blue('π (Projection/프로젝트)', '특정 열 선택 (SELECT col)'),
          _Item.def('⋈ (Join/조인)', '두 릴레이션을 조건으로 결합'),
          _Item.def('÷ (Division/디비전)', '나누기, 모든 조건 만족하는 행 반환'),
        ],
      ),

      // ─── 9. 보안 ──────────────────────────────────────────────────────
      _Section(
        title: '보안',
        icon: Icons.security,
        iconColor: const Color(0xFFFF5252),
        content: [
          _Item.header('── CIA 기본 개념 ──'),
          _Item.red('기밀성(Confidentiality)', '허가된 사용자만 접근, 암호화로 보호'),
          _Item.blue('무결성(Integrity)', '데이터 변조 방지, 해시·디지털서명'),
          _Item.def('가용성(Availability)', '정당한 사용자 언제든 접근 가능, DDoS 방어'),
          _Item.header('── 웹 공격 ──'),
          _Item.red('SQL Injection', "입력값에 SQL 삽입, 예) ' OR '1'='1 → 파라미터 바인딩으로 방어"),
          _Item.red('XSS(Cross-Site Scripting)', '악성 스크립트 삽입, 타 사용자 브라우저 실행 → 출력 인코딩'),
          _Item.red('CSRF', '인증된 사용자 권한으로 악의적 요청, CSRF 토큰으로 방어'),
          _Item.def('세션 하이재킹', '유효 세션 ID 탈취·도용, HTTPS+세션 타임아웃'),
          _Item.def('디렉토리 트래버설', '../을 이용해 허가되지 않은 디렉토리 접근'),
          _Item.header('── 네트워크 공격 ──'),
          _Item.red('DDoS', '분산 서비스 거부, 다수 좀비PC로 서버 과부하'),
          _Item.def('스니핑(Sniffing)', '네트워크 패킷 도청·분석'),
          _Item.def('스푸핑(Spoofing)', 'IP·MAC·DNS 주소 위장'),
          _Item.def('파밍(Pharming)', 'DNS 변조로 가짜 사이트로 유도'),
          _Item.def('피싱(Phishing)', '이메일·문자 등으로 위장해 정보 탈취'),
          _Item.def('APT(Advanced Persistent Threat)', '장기간 지속적·은밀한 표적 공격'),
          _Item.header('── 암호화 ──'),
          _Item.blue('대칭키(AES/DES)', '같은 키로 암복호화, 빠름, 키 분배 문제 → AES(128/256bit)'),
          _Item.red('비대칭키(RSA)', '공개키+개인키, 키 분배 안전, 느림, SSL/인증서'),
          _Item.def('해시(SHA/MD5)', '단방향 함수, 복호화 불가, MD5=128bit, SHA-256=256bit'),
          _Item.header('── 접근제어 ──'),
          _Item.def('MAC(강제적)', '보안 레이블, 관리자가 정책 결정'),
          _Item.def('DAC(임의적)', '자원 소유자가 접근 권한 결정'),
          _Item.blue('RBAC(역할기반)', '역할(Role)에 권한 부여, 기업에서 주로 사용'),
        ],
      ),

      // ─── 10. 운영체제 ─────────────────────────────────────────────────
      _Section(
        title: '운영체제 (OS)',
        icon: Icons.memory,
        iconColor: const Color(0xFF26A69A),
        content: [
          _Item.header('── 프로세스 상태 전이 ──'),
          _Item.red('생성(New)', '프로세스 생성, PCB 할당'),
          _Item.blue('준비(Ready)', 'CPU 할당 대기 (준비 큐)'),
          _Item.def('실행(Running)', 'CPU 점유 중, 실제 실행'),
          _Item.def('대기(Waiting)', 'I/O·이벤트 대기, CPU 반납'),
          _Item.def('완료(Terminated)', '실행 종료, PCB 해제'),
          _Item.header('── CPU 스케줄링 ──'),
          _Item.red('FCFS', '선입선출, 비선점, 호위 효과(Convoy) 발생'),
          _Item.blue('SJF', '짧은 작업 우선, 비선점, 기아(Starvation) 가능'),
          _Item.red('RR(Round Robin)', '시간 할당량(Time Quantum), 선점, 공평성'),
          _Item.def('Priority', '우선순위 기반, 기아→에이징(Aging)으로 해결'),
          _Item.def('SRT', 'SJF 선점 버전, 잔여 실행시간 최소 우선'),
          _Item.def('MLQ(다단계큐)', '여러 큐, 각 큐마다 다른 알고리즘'),
          _Item.header('── 교착상태(Deadlock) 4조건 ──'),
          _Item.red('상호배제', '자원은 한 번에 하나의 프로세스만 사용'),
          _Item.red('점유대기', '자원 점유 중에 다른 자원을 요청·대기'),
          _Item.red('비선점', '다른 프로세스의 자원 강제 빼앗기 불가'),
          _Item.red('환형대기', '프로세스들이 원형으로 서로 자원 대기'),
          _Item.blue('예방(Prevention)', '4조건 중 하나 제거, 자원 낭비'),
          _Item.def('회피(Avoidance)', '은행가 알고리즘, 안전 상태 유지'),
          _Item.def('탐지(Detection)', '교착상태 발생 허용 후 탐지·복구'),
          _Item.header('── 메모리 관리 ──'),
          _Item.blue('페이징(Paging)', '고정 크기 프레임, 외부단편화 없음, 내부단편화'),
          _Item.def('세그먼테이션', '가변 크기 세그먼트, 외부단편화, 보호 용이'),
          _Item.def('가상메모리', '실제보다 큰 메모리 사용, 요구 페이징'),
          _Item.header('── 페이지 교체 알고리즘 ──'),
          _Item.def('FIFO', '가장 오래된 페이지 교체, Belady 이상 발생 가능'),
          _Item.red('LRU', '가장 오래 사용 안 된 페이지 교체, 성능 우수'),
          _Item.def('LFU', '가장 참조 횟수 적은 페이지 교체'),
          _Item.def('OPT(최적)', '미래에 가장 오래 사용 안 될 페이지, 이론상 최적'),
        ],
      ),

      // ─── 11. SOLID 원칙 ───────────────────────────────────────────────
      _Section(
        title: 'SOLID 원칙 (객체지향)',
        icon: Icons.rule,
        iconColor: const Color(0xFFFFB300),
        content: [
          _Item.red('S - SRP (단일책임)', '클래스는 하나의 책임만, 변경 이유도 하나'),
          _Item.blue('O - OCP (개방폐쇄)', '확장에는 열려있고(Open), 수정에는 닫혀있음(Closed)'),
          _Item.def('L - LSP (리스코프치환)', '자식 클래스는 부모 클래스를 대체 가능해야 함'),
          _Item.def('I - ISP (인터페이스분리)', '클라이언트가 불필요한 인터페이스에 의존하지 않도록 분리'),
          _Item.red('D - DIP (의존역전)', '추상화에 의존, 구체화에 의존 금지 (인터페이스 통해 의존)'),
          _Item.header('── 기억법 ──'),
          _Item.def('SOLID', 'S=단일, O=개폐, L=리스코프, I=인터분리, D=의존역전'),
        ],
      ),

      // ─── 12. 프로그래밍 핵심 ─────────────────────────────────────────
      _Section(
        title: '프로그래밍 핵심',
        icon: Icons.code,
        iconColor: const Color(0xFF80CBC4),
        content: [
          _Item.header('── C언어 포인터 ──'),
          _Item.red('int *p', 'p는 int를 가리키는 포인터'),
          _Item.def('*p', '포인터가 가리키는 주소의 값 (역참조)'),
          _Item.def('&a', '변수 a의 주소'),
          _Item.blue('p++', '포인터 산술: int형이면 4바이트 이동'),
          _Item.header('── Java 핵심 ──'),
          _Item.red('오버로딩(Overloading)', '같은 이름, 다른 매개변수 → 컴파일 타임 다형성'),
          _Item.blue('오버라이딩(Overriding)', '부모 메서드 재정의 → 런타임 다형성'),
          _Item.def('추상클래스', 'abstract 키워드, 인스턴스 생성 불가, 일부 구현 가능'),
          _Item.def('인터페이스', '모든 메서드 추상, 다중 상속 가능, implements'),
          _Item.header('── Python 슬라이싱 ──'),
          _Item.def('a[1:4]', '인덱스 1~3 (끝 미포함)'),
          _Item.def('a[::-1]', '전체 역순'),
          _Item.def('a[::2]', '2칸 간격으로'),
          _Item.def('a[-1]', '마지막 원소'),
          _Item.header('── 재귀 패턴 ──'),
          _Item.def('팩토리얼', 'fact(n) = n * fact(n-1), base: fact(0)=1'),
          _Item.def('피보나치', 'fib(n) = fib(n-1) + fib(n-2), base: fib(0)=0, fib(1)=1'),
          _Item.def('GCD(유클리드)', 'gcd(a,b) = gcd(b, a%b), base: gcd(a,0)=a'),
          _Item.header('── 정렬 알고리즘 복잡도 ──'),
          _Item.red('버블(Bubble)', 'O(n²) / O(n²) / O(n) — 인접 비교교환'),
          _Item.def('선택(Selection)', 'O(n²) / O(n²) / O(n²) — 최솟값 선택'),
          _Item.def('삽입(Insertion)', 'O(n²) / O(n²) / O(n) — 이미 정렬 시 빠름'),
          _Item.red('퀵(Quick)', 'O(nlogn) / O(nlogn) / O(n²) — pivot 분할, 평균 최고'),
          _Item.blue('병합(Merge)', 'O(nlogn) / O(nlogn) / O(nlogn) — 안정, 공간 O(n)'),
          _Item.def('복잡도 표기', '최선 / 평균 / 최악 순'),
        ],
      ),

      // ─── 13. 결합도와 응집도 ─────────────────────────────────────────
      _Section(
        title: '결합도 & 응집도',
        icon: Icons.link,
        iconColor: const Color(0xFFFF8A65),
        content: [
          _Item.header('── 결합도 (낮을수록 좋음 ↓) ──'),
          _Item.blue('자료(Data)', '단순 자료만 전달, 가장 낮음 ★Best★'),
          _Item.def('스탬프(Stamp)', '자료구조(구조체·배열) 전달'),
          _Item.def('제어(Control)', '제어 흐름에 영향 주는 값(플래그) 전달'),
          _Item.def('외부(External)', '외부 환경(공통 외부 데이터) 공유'),
          _Item.def('공통(Common)', '전역 데이터(변수) 공유'),
          _Item.red('내용(Content)', '다른 모듈 내부 직접 참조·수정, 가장 나쁨 ✗Worst✗'),
          _Item.header('── 응집도 (높을수록 좋음 ↑) ──'),
          _Item.blue('기능(Functional)', '모든 요소가 하나의 기능에 기여, 가장 높음 ★Best★'),
          _Item.def('순차(Sequential)', '이전 활동 출력이 다음 활동 입력'),
          _Item.def('통신(Communicational)', '같은 입력/출력 데이터를 사용'),
          _Item.def('절차(Procedural)', '특정 순서로 수행되어야 하는 기능'),
          _Item.def('시간(Temporal)', '같은 시간대에 실행되는 기능 모음'),
          _Item.def('논리(Logical)', '유사한 성격의 기능, 호출 시 선택'),
          _Item.red('우연(Coincidental)', '관련 없는 기능의 묶음, 가장 낮음 ✗Worst✗'),
          _Item.header('── 기억법 ──'),
          _Item.def('결합도', '자스제외공내 (높은→낮은: 내용→공통→외부→제어→스탬프→자료)'),
          _Item.def('응집도', '우논시절통순기 (낮은→높은: 우연→논리→시간→절차→통신→순차→기능)'),
        ],
      ),
    ];
  }
}

// ─── 데이터 모델 ─────────────────────────────────────────────────────────────

enum _ItemType { header, red, blue, normal }

class _Item {
  final String term;
  final String definition;
  final _ItemType type;

  const _Item(this.term, this.definition, this.type);

  factory _Item.header(String label) => _Item(label, '', _ItemType.header);
  factory _Item.red(String term, String def) => _Item(term, def, _ItemType.red);
  factory _Item.blue(String term, String def) =>
      _Item(term, def, _ItemType.blue);
  factory _Item.def(String term, String def) =>
      _Item(term, def, _ItemType.normal);
}

class _Section {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<_Item> content;
  final bool isTable;
  final List<String> tableHeaders;
  final List<List<String>> tableRows;

  const _Section({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.content,
    this.isTable = false,
    this.tableHeaders = const [],
    this.tableRows = const [],
  });
}

// ─── 섹션 카드 위젯 ───────────────────────────────────────────────────────────

class _SectionCard extends StatefulWidget {
  final _Section section;
  const _SectionCard({super.key, required this.section});

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.section;
    final itemCount = s.isTable ? s.tableRows.length : s.content.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Card(
        color: AppConfig.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: _expanded
                ? s.iconColor.withAlpha(128)
                : AppConfig.borderColor,
            width: _expanded ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
            splashColor: s.iconColor.withAlpha(26),
          ),
          child: ExpansionTile(
            initiallyExpanded: false,
            onExpansionChanged: (v) => setState(() => _expanded = v),
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: s.iconColor.withAlpha(38),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(s.icon, color: s.iconColor, size: 22),
            ),
            title: Text(
              s.title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: s.iconColor.withAlpha(51),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$itemCount개',
                    style: TextStyle(
                      color: s.iconColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.white54,
                ),
              ],
            ),
            children: [
              const Divider(color: Color(0xFF3C3C3C), height: 1),
              if (s.isTable)
                _TableContent(
                    headers: s.tableHeaders, rows: s.tableRows)
              else
                _ListContent(items: s.content),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 리스트 콘텐츠 ────────────────────────────────────────────────────────────

class _ListContent extends StatelessWidget {
  final List<_Item> items;
  const _ListContent({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;

          if (item.type == _ItemType.header) {
            return Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.term,
                      style: TextStyle(
                        color: Colors.white.withAlpha(153),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          final isEven = i % 2 == 0;
          Color termColor;
          switch (item.type) {
            case _ItemType.red:
              termColor = const Color(0xFFFF6B6B);
              break;
            case _ItemType.blue:
              termColor = const Color(0xFF64B5F6);
              break;
            default:
              termColor = Colors.white;
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 2),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: isEven
                  ? Colors.white.withAlpha(5)
                  : Colors.white.withAlpha(10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 148,
                  child: Text(
                    item.term,
                    style: TextStyle(
                      color: termColor,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.definition,
                    style: TextStyle(
                      color: Colors.white.withAlpha(204),
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── 테이블 콘텐츠 ────────────────────────────────────────────────────────────

class _TableContent extends StatelessWidget {
  final List<String> headers;
  final List<List<String>> rows;

  const _TableContent(
      {super.key, required this.headers, required this.rows});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: TableBorder.all(
          color: AppConfig.borderColor,
          width: 1,
          borderRadius: BorderRadius.circular(8),
        ),
        children: [
          // Header row
          TableRow(
            decoration: BoxDecoration(
              color: AppConfig.primaryColor.withAlpha(51),
            ),
            children: headers
                .map((h) => Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Text(
                        h,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ))
                .toList(),
          ),
          // Data rows
          ...rows.asMap().entries.map((entry) {
            final i = entry.key;
            final row = entry.value;
            return TableRow(
              decoration: BoxDecoration(
                color: i % 2 == 0
                    ? Colors.white.withAlpha(5)
                    : Colors.white.withAlpha(13),
              ),
              children: row
                  .map((cell) => Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        child: Text(
                          cell,
                          style: TextStyle(
                            color: Colors.white.withAlpha(204),
                            fontSize: 12,
                          ),
                        ),
                      ))
                  .toList(),
            );
          }),
        ],
      ),
    );
  }
}
