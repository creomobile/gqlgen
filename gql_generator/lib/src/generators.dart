// this tile is needed becouse of flutter tests
// cannot be runned with this import:
// import 'package:source_gen/source_gen.dart';

class Generators {
  static const keywords = {'true', 'false'};

  static String _header(String header) => '\n// --- $header\n\n';

  static String createBase() {
    return '''
${_header('Base')}
abstract class ObjectBase {
  const ObjectBase(this.json);
  final Map<String, dynamic> json;
}
''';
  }

  static String createEnums(List<Type> types) {
    var res = _header('Enums');

    types.forEach((type) {
      final name = type.name;
      final valueNames = type.enumValues.map((_) => _.name).toList();
      final valuesMap =
          Map<String, String>.fromIterables(valueNames, valueNames.map((_) {
        final res = _.toCamelCase();
        return keywords.contains(res) ? res + '_' : res;
      }));
      final mapTxt =
          valuesMap.entries.map((_) => '\'${_.key}\':${_.value}').join(',');
      final constsTxt = valuesMap.entries
          .map((_) => 'static const ${_.value} = $name._(\'${_.key}\');')
          .join();

      res += '''
class $name {
  factory $name(String value) => _map[value];
  const $name._(this._value);
  final String _value;
  static const _map = {$mapTxt};

  $constsTxt

  @override
  String toString() => _value;

  @override
  bool operator ==(_) => _ is $name && _value == _._value;
  @override
  int get hashCode => _value.hashCode;
}
''';
    });

    return res;
  }

  static String createInterfaces(
      List<Type> types, Map<String, Type> knownTypes, Set<String> customTypes) {
    var res = _header('Interfaces');

    types.forEach((type) {
      final name = type.name;
      final interfaceFields = <String>{};
      res += '''
mixin $name on ObjectBase {
  ${_createFields(type.fields, knownTypes, customTypes, interfaceFields)}
}

class _$name extends ObjectBase with $name {
  _$name(Map<String, dynamic> json) : super(json);
}
''';
    });

    return res;
  }

  static String createObjects(
      List<Type> types, Map<String, Type> knownTypes, Set<String> customTypes) {
    var res = _header('Objects');

    types.forEach((type) {
      final name = type.name;
      final interfaces = type.interfaces
              ?.map((_) => knownTypes[_.name])
              ?.where((_) => _ != null)
              ?.toList() ??
          [];
      final interfaceFields = interfaces
          .map((_) => _.fields)
          .expand((_) => _)
          .map((_) => _.name)
          .toSet();
      final mixins = interfaces.isEmpty
          ? ''
          : ' with ' + interfaces.map((_) => _.name).join(',');
      res += '''
class $name extends ObjectBase$mixins {
  ${mixins.isEmpty ? 'const ' : ''}$name(Map<String, dynamic> json) : super(json);

  ${_createFields(type.fields, knownTypes, customTypes, interfaceFields)}
}
''';
    });

    return res;
  }

  static String createExtensions(List<Type> interfaces, List<Type> objects) {
    var res = _header('Extensions');

    String createExtension(String name, [String prefix = '']) =>
        '$name as$name() => $prefix$name(this);\n';

    res += '''
extension GqlExtension on Map<String, dynamic> {
  ${interfaces.map((_) => createExtension(_.name, '_')).join()}
  ${objects.map((_) => createExtension(_.name)).join()}
}
''';

    return res;
  }

  static String createInputObjects(
      List<Type> types, Map<String, Type> knownTypes, Set<String> customTypes) {
    var res = _header('Input Objects');

    types.forEach((type) {
      final name = type.name;
      final interfaces = type.interfaces
              ?.map((_) => knownTypes[_.name])
              ?.where((_) => _ != null)
              ?.toList() ??
          [];
      final interfaceFields = interfaces
          .map((_) => _.fields)
          .expand((_) => _)
          .map((_) => _.name)
          .toSet();
      final mixins = interfaces.isEmpty
          ? ''
          : ' with ' + interfaces.map((_) => _.name).join(',');
      final constStr = mixins.isEmpty ? 'const ' : '';
      res += '''
class $name extends ObjectBase$mixins {
  $constStr$name(Map<String, dynamic> json) : super(json);
  $constStr$name.create() : super($constStr<String, dynamic>{});

  ${_createFields(type.inputFields, knownTypes, customTypes, interfaceFields)}
}
''';
    });

    return res;
  }

  static String _getType(
      FieldType type, Map<String, Type> knownTypes, Set<String> customTypes) {
    if (customTypes.contains(type.name)) return type.name;
    switch (type.kind) {
      case Kind.nonNull:
        return _getType(type.ofType, knownTypes, customTypes);
      case Kind.list:
        return 'Iterable<${_getType(type.ofType, knownTypes, customTypes)}>';
      case Kind.scalar:
        switch (type.name) {
          case 'String':
            return 'String';
          case 'Boolean':
            return 'bool';
          case 'Int':
            return 'int';
          case 'DateTime':
            return 'DateTime';
          case 'Float':
            return 'double';
        }
        return 'dynamic';
      case Kind.enum_:
        return type.name;
      case Kind.object:
      case Kind.inputObject:
      case Kind.interface:
        return knownTypes.containsKey(type.name) ? type.name : 'dynamic';
      default:
        return 'dynamic';
    }
  }

  static String _getGetter(String data, FieldType type,
      Map<String, Type> knownTypes, Set<String> customTypes) {
    if (customTypes.contains(type.name)) return '${type.name}($data)';
    switch (type.kind) {
      case Kind.nonNull:
        return _getGetter(data, type.ofType, knownTypes, customTypes);
      case Kind.list:
        return '($data as List).map((_) => '
            '${_getGetter('_', type.ofType, knownTypes, customTypes)})';
      case Kind.enum_:
      case Kind.object:
      case Kind.inputObject:
        return '${type.name}($data)';
      case Kind.interface:
        return '_${type.name}($data)';
      default:
        return data;
    }
  }

  static String _getSetter(String data, FieldType type,
      Map<String, Type> knownTypes, Set<String> customTypes) {
    if (customTypes.contains(type.name)) return '$data.json';
    switch (type.kind) {
      case Kind.nonNull:
        return _getSetter(data, type.ofType, knownTypes, customTypes);
      case Kind.list:
        return '$data.map((_) => '
            '${_getSetter('_', type.ofType, knownTypes, customTypes)})'
            '.toList()';
      case Kind.enum_:
        return '$data.toString()';
      case Kind.object:
      case Kind.inputObject:
      case Kind.interface:
        return '$data.json';
      default:
        return data;
    }
  }

  static String _createFields(
      Iterable<FieldBase> fields,
      Map<String, Type> knownTypes,
      Set<String> customTypes,
      Set<String> interfaceFields) {
    return fields.where((_) => !interfaceFields.contains(_.name)).map((field) {
      final name = field.name;
      final camel = name.toCamelCase();
      final comment = field.description?.isNotEmpty == true
          ? field.description.split('\n').map((_) => '/// ${_.trim()}\n').join()
          : '';
      final deprecated = field is Field && field.isDeprecated
          ? '@Deprecated(\'${field.deprecationReason ?? ''}\')\n'
          : '';
      final type = _getType(field.type, knownTypes, customTypes);
      final getter =
          _getGetter('json[\'$name\']', field.type, knownTypes, customTypes);
      final completeGetter =
          '$comment$deprecated$type get $camel => $getter;\n';
      final setter = _getSetter('value', field.type, knownTypes, customTypes);
      final completeSetter =
          'set $camel($type value) => json[\'$name\'] = $setter;\n';

      return completeGetter + completeSetter;
    }).join();
  }
}

// extensions

extension StringExtentions on String {
  String capitalize() => this?.isNotEmpty != true
      ? this
      : this[0].toUpperCase() + this.substring(1);
  String uncapitalize() => this?.isNotEmpty != true
      ? this
      : this[0].toLowerCase() + this.substring(1);
  bool isUppercase() => !this
      .runes
      .map((_) => String.fromCharCode(_))
      .any((_) => _.toUpperCase() != _);
  String camelToText() {
    final codes = this
        .runes
        .skip(1)
        .map((p) => String.fromCharCode(p))
        .map((p) => p.toUpperCase() == p ? ' $p' : p)
        .expand((p) => p.runes);

    return this[0].toUpperCase() + String.fromCharCodes(codes);
  }

  List<String> camelToWords() => this
      .camelToText()
      .split(' ')
      .map((_) => _.trim())
      .where((_) => _.isNotEmpty)
      .toList();

  String toCamelCase() {
    String getCamelCase(List<String> words) {
      final lower = words.map((_) => _.toLowerCase());
      return [lower.first, ...lower.skip(1).map((_) => _.capitalize())].join();
    }

    var words = this.split('_');
    if (words.length > 1) return getCamelCase(words);
    if (this.isUppercase()) return this.toLowerCase();
    return getCamelCase(this.camelToWords());
  }
}

// adapters

abstract class Adapter {
  Adapter(this.map);
  final Map<String, dynamic> map;

  String get name => map['name'];
  String get description => map['description'];
}

class Type extends Adapter {
  Type(Map<String, dynamic> map) : super(map);

  Kind get kind => getKind(map['kind']);
  Iterable<Field> get fields =>
      (map['fields'] as List)?.map((_) => Field(_)) ?? [];
  Iterable<InputField> get inputFields =>
      (map['inputFields'] as List)?.map((_) => InputField(_)) ?? [];
  Iterable<FieldType> get interfaces =>
      (map['interfaces'] as List)?.map((_) => FieldType(_)) ?? [];
  Iterable<EnumValue> get enumValues =>
      (map['enumValues'] as List)?.map((_) => EnumValue(_)) ?? [];
  Iterable<FieldType> get possibleTypes =>
      (map['possibleTypes'] as List)?.map((_) => FieldType(_)) ?? [];
}

class EnumValue extends Adapter {
  EnumValue(Map<String, dynamic> map) : super(map);
  bool get isDeprecated => map['isDeprecated'];
  String get deprecationReason => map['deprecationReason'];
}

class FieldBase extends Adapter {
  FieldBase(Map<String, dynamic> map) : super(map);
  FieldType get type => FieldType(map['type']);
}

class Field extends FieldBase {
  Field(Map<String, dynamic> map) : super(map);
  Iterable<Arg> get args => (map['args'] as List)?.map((_) => Arg(_)) ?? [];
  bool get isDeprecated => map['isDeprecated'];
  String get deprecationReason => map['deprecationReason'];
}

class InputField extends FieldBase {
  InputField(Map<String, dynamic> map) : super(map);
  dynamic get defaultValue => map['defaultValue'];
}

class Arg extends Adapter {
  Arg(Map<String, dynamic> map) : super(map);
  FieldType get type => FieldType(map['type']);
  dynamic get defaultValue => map['defaultValue'];
}

class FieldType {
  FieldType(this.map);
  final Map<String, dynamic> map;
  Kind get kind => getKind(map['kind']);
  String get name => map['name'];
  FieldType get ofType => FieldType(map['ofType']);
}

enum Kind {
  unknown,
  scalar,
  object,
  interface,
  union,
  enum_,
  inputObject,
  list,
  nonNull,
}

Kind getKind(String kind) {
  switch (kind) {
    case 'SCALAR':
      return Kind.scalar;
    case 'OBJECT':
      return Kind.object;
    case 'INTERFACE':
      return Kind.interface;
    case 'UNION':
      return Kind.union;
    case 'ENUM':
      return Kind.enum_;
    case 'INPUT_OBJECT':
      return Kind.inputObject;
    case 'LIST':
      return Kind.list;
    case 'NON_NULL':
      return Kind.nonNull;
    default:
      return Kind.unknown;
  }
}

const String query = r'''
query IntrospectionQuery {
      __schema {
        types {
          ...FullType
        }
      }
    }

    fragment FullType on __Type {
      kind
      name
      description
      fields(includeDeprecated: true) {
        name
        description
        args {
          ...InputValue
        }
        type {
          ...TypeRef
        }
        isDeprecated
        deprecationReason
      }
      inputFields {
        ...InputValue
      }
      interfaces {
        ...TypeRef
      }
      enumValues(includeDeprecated: true) {
        name
        description
        isDeprecated
        deprecationReason
      }
      possibleTypes {
        ...TypeRef
      }
    }

    fragment InputValue on __InputValue {
      name
      description
      type { ...TypeRef }
      defaultValue
    }

    fragment TypeRef on __Type {
      kind
      name
      ofType {
        kind
        name
        ofType {
          kind
          name
          ofType {
            kind
            name
            ofType {
              kind
              name
              ofType {
                kind
                name
                ofType {
                  kind
                  name
                  ofType {
                    kind
                    name
                  }
                }
              }
            }
          }
        }
      }
    }
''';
