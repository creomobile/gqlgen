import 'dart:async';
import 'dart:convert';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:gql_annotation/gql_annotation.dart';
import 'package:gql_generator/src/generators.dart';
import 'package:http/http.dart' as http;
import 'package:source_gen/source_gen.dart';

class GraphQLGenerator extends GeneratorForAnnotation<GraphQLSource> {
  bool isSystem(String name) => name?.startsWith('__');

  @override
  FutureOr<String> generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) async {
    final url = annotation.read('url').stringValue;
    final customTypes = annotation.read('customTypes').isNull
        ? <String>{}
        : annotation
            .read('customTypes')
            .listValue
            .map((_) => _.toStringValue())
            .toSet();
    final response = await http.post(url,
        headers: {'content-type': 'application/json'},
        body: json.encode({'query': query}));
    final types =
        (json.decode(response.body)['data']['__schema']['types'] as List)
            .map((_) => Type(_))
            .where((_) => !isSystem(_.name));
    final kindMap = <Kind, List<Type>>{};
    types.forEach((_) => (kindMap[_.kind] ??= <Type>[]).add(_));
    final knownTypes = Map<String, Type>.fromIterable([
      ...kindMap[Kind.enum_],
      ...kindMap[Kind.interface],
      ...kindMap[Kind.object],
    ], key: (_) => _.name);

    return Generators.createBase() +
        Generators.createEnums(kindMap[Kind.enum_]) +
        Generators.createInterfaces(
            kindMap[Kind.interface], knownTypes, customTypes) +
        Generators.createObjects(
            kindMap[Kind.object], knownTypes, customTypes) +
        Generators.createExtensions(
            kindMap[Kind.interface], kindMap[Kind.object]) +
        Generators.createInputObjects(
            kindMap[Kind.inputObject], knownTypes, customTypes);
  }
}
