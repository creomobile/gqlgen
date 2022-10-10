import 'dart:async';
import 'dart:convert';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:gql_annotation/gql_annotation.dart';
import 'package:gql_generator/src/generators.dart';
import 'package:http/http.dart' as http;
import 'package:source_gen/source_gen.dart';

class GraphQLGenerator extends GeneratorForAnnotation<GraphQLSource> {
  bool isSystem(String name) => name.startsWith('__');

  @override
  FutureOr<String> generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) async {
    final baseName = element.name!;
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError('Generator cannot target `$baseName`.',
          todo: 'Remove the GraphQLSource annotation from `$baseName`.',
          element: element);
    }

    final url = annotation.read('url').stringValue;
    final customTypes = annotation.read('customTypes').isNull
        ? <String>{}
        : annotation
            .read('customTypes')
            .listValue
            .map((_) => _.toStringValue()!)
            .toSet();
    final response = await http.post(Uri.parse(url),
        headers: {'content-type': 'application/json'},
        body: json.encode({'query': query}));
    final types =
        (json.decode(response.body)['data']['__schema']['types'] as List)
            .map((_) => Type(_))
            .where((_) => !isSystem(_.name));
    final kindMap = <Kind, List<Type>>{};
    types.forEach((_) => (kindMap[_.kind] ??= <Type>[]).add(_));
    final knownTypes = Map<String, Type>.fromIterable([
      ...kindMap[Kind.enum_] ?? [],
      ...kindMap[Kind.interface] ?? [],
      ...kindMap[Kind.object] ?? [],
      ...kindMap[Kind.inputObject] ?? [],
    ], key: (_) => _.name);

    final result = Generators.createEnums(
            kindMap[Kind.enum_] ?? [], customTypes) +
        Generators.createInterfaces(
            baseName, kindMap[Kind.interface] ?? [], knownTypes, customTypes) +
        Generators.createObjects(
            baseName, kindMap[Kind.object] ?? [], knownTypes, customTypes) +
        Generators.createExtensions(
            kindMap[Kind.interface] ?? [], kindMap[Kind.object] ?? []) +
        Generators.createInputObjects(
            baseName, kindMap[Kind.inputObject] ?? [], knownTypes, customTypes);

    return result;
  }
}
