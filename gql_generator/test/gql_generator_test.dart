import 'package:flutter_test/flutter_test.dart';
import 'package:gql_generator/src/generators.dart';

void main() {
  test('toCamelCase test', () {
    expect('TEST_STRING1'.toCamelCase(), 'testString1');
    expect('TESTSTRING2'.toCamelCase(), 'teststring2');
    expect('test_string3'.toCamelCase(), 'testString3');
    expect('TestString4'.toCamelCase(), 'testString4');
    expect('testString5'.toCamelCase(), 'testString5');
  });
}
