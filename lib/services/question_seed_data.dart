import '../models/question.dart';

class QuestionSeedData {
  static final List<Question> questions = [
    // === 코드 읽기 (C) ===
    Question(
      year: 2024,
      round: 1,
      subject: '프로그래밍',
      questionType: 'code_reading',
      questionText: '다음 C 프로그램의 실행 결과를 쓰시오.',
      codeSnippet: '''#include <stdio.h>
int main() {
    int a = 5, b = 3;
    int *p = &a;
    int *q = &b;
    *p = *p + *q;
    printf("%d %d", a, b);
    return 0;
}''',
      codeLanguage: 'c',
      answer: '8 3',
      explanation: 'p는 a를 가리키므로 *p = 5+3 = 8. b는 변경되지 않아 3. 출력: "8 3"',
      difficulty: 2,
      frequencyWeight: 0.9,
    ),
    Question(
      year: 2024,
      round: 2,
      subject: '프로그래밍',
      questionType: 'code_reading',
      questionText: '다음 C 프로그램의 실행 결과를 쓰시오.',
      codeSnippet: '''#include <stdio.h>
int main() {
    int arr[] = {1, 2, 3, 4, 5};
    int sum = 0;
    for (int i = 0; i < 5; i++) {
        if (arr[i] % 2 == 1)
            sum += arr[i];
    }
    printf("%d", sum);
    return 0;
}''',
      codeLanguage: 'c',
      answer: '9',
      explanation: '홀수만 합산: 1 + 3 + 5 = 9',
      difficulty: 2,
      frequencyWeight: 0.85,
    ),

    // === 코드 읽기 (Java) ===
    Question(
      year: 2023,
      round: 3,
      subject: '프로그래밍',
      questionType: 'code_reading',
      questionText: '다음 Java 프로그램의 실행 결과를 쓰시오.',
      codeSnippet: '''class Parent {
    int x = 10;
    void display() {
        System.out.println("Parent: " + x);
    }
}
class Child extends Parent {
    int x = 20;
    void display() {
        System.out.println("Child: " + x);
    }
}
public class Main {
    public static void main(String[] args) {
        Parent obj = new Child();
        obj.display();
        System.out.println(obj.x);
    }
}''',
      codeLanguage: 'java',
      answer: 'Child: 20\n10',
      explanation:
          '메서드는 동적 바인딩(오버라이딩)되어 Child의 display() 호출 → "Child: 20". '
          '필드는 정적 바인딩되어 Parent의 x=10 출력.',
      difficulty: 4,
      frequencyWeight: 0.95,
    ),
    Question(
      year: 2025,
      round: 1,
      subject: '프로그래밍',
      questionType: 'code_reading',
      questionText: '다음 Java 프로그램의 실행 결과를 쓰시오.',
      codeSnippet: '''abstract class Shape {
    abstract double area();
    void info() {
        System.out.println("넓이: " + area());
    }
}
class Circle extends Shape {
    double r;
    Circle(double r) { this.r = r; }
    double area() { return 3.14 * r * r; }
}
public class Main {
    public static void main(String[] args) {
        Shape s = new Circle(5);
        s.info();
    }
}''',
      codeLanguage: 'java',
      answer: '넓이: 78.5',
      explanation:
          'Circle(5)에서 r=5. area() = 3.14 * 25 = 78.5. info()가 area()를 호출하여 "넓이: 78.5" 출력.',
      difficulty: 3,
      frequencyWeight: 0.9,
    ),

    // === SQL ===
    Question(
      year: 2024,
      round: 1,
      subject: 'SQL',
      questionType: 'sql',
      questionText:
          '학생(Student) 테이블과 수강(Enrollment) 테이블이 있을 때, 다음 SQL의 실행 결과를 쓰시오.\n\n'
          '[Student]\n학번 | 이름\n101 | 김철수\n102 | 이영희\n103 | 박민수\n\n'
          '[Enrollment]\n학번 | 과목\n101 | DB\n101 | 자료구조\n102 | DB',
      codeSnippet: '''SELECT S.이름, COUNT(E.과목) AS 수강수
FROM Student S
LEFT JOIN Enrollment E ON S.학번 = E.학번
GROUP BY S.이름
ORDER BY 수강수 DESC;''',
      codeLanguage: 'sql',
      answer: '김철수 2\n이영희 1\n박민수 0',
      explanation:
          'LEFT JOIN이므로 수강이 없는 박민수도 포함. 김철수 2과목, 이영희 1과목, 박민수 0과목. DESC 정렬.',
      difficulty: 3,
      frequencyWeight: 0.95,
    ),
    Question(
      year: 2023,
      round: 2,
      subject: 'SQL',
      questionType: 'sql',
      questionText:
          '성적(Grade) 테이블에서 다음 SQL의 실행 결과를 쓰시오.\n\n'
          '[Grade]\n학번 | 과목 | 점수\n101 | DB | 85\n101 | OS | 90\n102 | DB | 70\n102 | OS | 60\n103 | DB | 95',
      codeSnippet: '''SELECT 과목, AVG(점수) AS 평균
FROM Grade
GROUP BY 과목
HAVING AVG(점수) >= 80;''',
      codeLanguage: 'sql',
      answer: 'DB 83.33\nOS 75는 제외 → DB만 출력',
      explanation:
          'DB 평균: (85+70+95)/3 ≈ 83.33. OS 평균: (90+60)/2 = 75. HAVING 조건(>=80)에 의해 DB만 출력.',
      difficulty: 3,
      frequencyWeight: 0.9,
    ),
    Question(
      year: 2025,
      round: 1,
      subject: 'SQL',
      questionType: 'sql',
      questionText:
          '사원(Employee) 테이블에서 다음 SQL의 실행 결과를 쓰시오.\n\n'
          '[Employee]\n사번 | 이름 | 부서 | 급여\n1 | 김 | 개발 | 5000\n2 | 이 | 인사 | 4000\n3 | 박 | 개발 | 6000\n4 | 최 | 인사 | 4500',
      codeSnippet: '''SELECT 이름, 급여
FROM Employee
WHERE 급여 > (SELECT AVG(급여) FROM Employee);''',
      codeLanguage: 'sql',
      answer: '박 6000\n김 5000',
      explanation:
          '전체 평균 급여 = (5000+4000+6000+4500)/4 = 4875. 4875보다 큰 급여: 김(5000), 박(6000).',
      difficulty: 3,
      frequencyWeight: 0.85,
    ),

    // === 단답형 암기 ===
    Question(
      year: 2024,
      round: 3,
      subject: '네트워크',
      questionType: 'short_answer',
      questionText: 'OSI 7계층을 아래에서 위로 순서대로 쓰시오.',
      answer: '물리, 데이터링크, 네트워크, 전송, 세션, 표현, 응용',
      explanation:
          'OSI 7계층: Physical → Data Link → Network → Transport → Session → Presentation → Application',
      difficulty: 2,
      frequencyWeight: 0.8,
    ),
    Question(
      year: 2023,
      round: 1,
      subject: '소프트웨어공학',
      questionType: 'short_answer',
      questionText:
          '객체의 생성을 서브클래스에 위임하여, 어떤 클래스의 인스턴스를 만들지를 서브클래스가 결정하게 하는 '
          '생성 디자인 패턴의 이름을 쓰시오.',
      answer: '팩토리 메서드',
      explanation:
          'Factory Method 패턴: 객체 생성 인터페이스를 정의하되, 인스턴스화할 클래스를 서브클래스에서 결정. '
          'GoF 생성 패턴 중 하나.',
      difficulty: 3,
      frequencyWeight: 0.85,
    ),
    Question(
      year: 2025,
      round: 1,
      subject: '소프트웨어공학',
      questionType: 'short_answer',
      questionText:
          '소프트웨어 테스트 기법 중, 입력 데이터의 경계값을 중심으로 테스트 케이스를 설계하는 기법의 이름을 쓰시오.',
      answer: '경계값 분석',
      explanation:
          'Boundary Value Analysis: 입력 조건의 경계(최소, 최소+1, 최대-1, 최대)에서 '
          '오류가 발생할 확률이 높으므로 경계값을 집중 테스트하는 블랙박스 테스트 기법.',
      difficulty: 2,
      frequencyWeight: 0.8,
    ),
  ];
}
