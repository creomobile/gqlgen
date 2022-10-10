// this tile is needed becouse of flutter tests
// cannot be runned with this import:
// import 'package:source_gen/source_gen.dart';

class Generators {
  static const keywords = {
    'true',
    'false',
    'default',
    'int',
    'float',
    'string',
    'bool'
  };

  static String _header(String header) => '\n// --- $header\n\n';

  static String createEnums(List<Type> types, Set<String> customTypes) {
    var res = _header('Enums');

    types.forEach((type) {
      final enumName = type.name;
      if (customTypes.contains(enumName)) return;

      final mapTxts = <String>[];
      final constTxts = <String>[];

      type.enumValues.forEach((enumValue) {
        final name = enumValue.name;
        var preparedName = name.toCamelCase();
        if (keywords.contains(preparedName)) preparedName += '_';
        mapTxts.add('\'${name}\':${preparedName}');

        var constValue =
            'static const ${preparedName} = $enumName._(\'${name}\');';

        final description = enumValue.description;

        if (description?.isNotEmpty == true) {
          constValue = '/// ${description}\n' + constValue;
        }

        constTxts.add(constValue);
      });

      res += '''
${type.description?.isNotEmpty == true ? '/// ${type.description}' : ''}
class $enumName {
  factory $enumName(String value) => _map[value]!;
  const $enumName._(this._value);
  final String _value;
  static const _map = {${mapTxts.join(',')}};

  ${constTxts.join()}

  @override
  String toString() => _value;

  @override
  bool operator ==(other) => other is $enumName && _value == other._value;
  @override
  int get hashCode => _value.hashCode;
}
''';
    });

    return res;
  }

  static String createInterfaces(String baseName, List<Type> types,
      Map<String, Type> knownTypes, Set<String> customTypes) {
    var res = _header('Interfaces');

    types.forEach((type) {
      final name = type.name;
      final interfaceFields = <String>{};
      res += '''
${type.description?.isNotEmpty == true ? '/// ${type.description}' : ''}
mixin $name on $baseName {
  ${_createFields(type.fields, knownTypes, customTypes, interfaceFields)}
}

class _$name extends $baseName with $name {
  _$name(Map<String, dynamic> json) : super(json);
}
''';
    });

    return res;
  }

  static String createObjects(String baseName, List<Type> types,
      Map<String, Type> knownTypes, Set<String> customTypes) {
    var res = _header('Objects');

    types.forEach((type) {
      final name = type.name;
      if (customTypes.contains(name)) return;
      final interfaces = type.interfaces
          .map((_) => knownTypes[_.name])
          .where((_) => _ != null)
          .cast<Type>()
          .toList();
      final interfaceFields = interfaces
          .map((_) => _.fields)
          .expand((_) => _)
          .map((_) => _.name)
          .toSet();
      final mixins = interfaces.isEmpty
          ? ''
          : ' with ' + interfaces.map((_) => _.name).join(',');
      res += '''
${type.description?.isNotEmpty == true ? '/// ${type.description}' : ''}
class $name extends $baseName$mixins {
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

  static String createInputObjects(String baseName, List<Type> types,
      Map<String, Type> knownTypes, Set<String> customTypes) {
    var res = _header('Input Objects');

    types.forEach((type) {
      final name = type.name;
      final interfaces = type.interfaces
          .map((_) => knownTypes[_.name])
          .where((_) => _ != null)
          .cast<Type>()
          .toList();
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
${type.description?.isNotEmpty == true ? '/// ${type.description}' : ''}
class $name extends $baseName$mixins {
  $constStr$name(Map<String, dynamic> json) : super(json);
  $constStr$name.create() : super($constStr<String, dynamic>{});

  ${_createFields(type.inputFields, knownTypes, customTypes, interfaceFields)}
}
''';
    });

    return res;
  }

  static String _getType(
      FieldType type, Map<String, Type> knownTypes, Set<String> customTypes,
      [bool isNullable = true]) {
    String result;

    if (customTypes.contains(type.name)) {
      result = type.name!;
    } else {
      switch (type.kind) {
        case Kind.nonNull:
          result = _getType(
              type.ofType, knownTypes, customTypes, isNullable = false);
          break;
        case Kind.list:
          result =
              'Iterable<${_getType(type.ofType, knownTypes, customTypes)}>';
          break;
        case Kind.scalar:
          switch (type.name) {
            case 'String':
              result = 'String';
              break;
            case 'Boolean':
              result = 'bool';
              break;
            case 'Int':
              result = 'int';
              break;
            case 'DateTime':
              result = 'DateTime';
              break;
            case 'Float':
              result = 'double';
              break;
            default:
              result = 'dynamic';
              break;
          }
          break;
        case Kind.enum_:
          result = type.name!;
          break;
        case Kind.object:
        case Kind.inputObject:
        case Kind.interface:
          result =
              knownTypes.containsKey(type.name ?? '') ? type.name! : 'dynamic';
          break;
        default:
          result = 'dynamic';
          break;
      }
    }

    if (isNullable && result != 'dynamic') result += '?';
    return result;
  }

  static String _getGetter(String data, FieldType type,
      Map<String, Type> knownTypes, Set<String> customTypes,
      [bool isNullable = true]) {
    if (customTypes.contains(type.name)) return '${type.name}($data)';
    switch (type.kind) {
      case Kind.nonNull:
        return _getGetter(
            data, type.ofType, knownTypes, customTypes, isNullable = false);
      case Kind.list:
        final getter = '($data as List).map((_) => '
            '${_getGetter('_', type.ofType, knownTypes, customTypes)})';
        return isNullable ? '$data == null ? null : $getter' : '$getter';
      case Kind.enum_:
      case Kind.object:
      case Kind.inputObject:
        final getter = '${type.name}($data)';
        return isNullable ? '$data == null ? null : $getter' : '$getter';
      case Kind.interface:
        final getter = '_${type.name}($data)';
        return isNullable ? '$data == null ? null : $getter' : '$getter';
      default:
        return data;
    }
  }

  static String _getSetter(String data, FieldType type,
      Map<String, Type> knownTypes, Set<String> customTypes,
      [bool isNullable = true]) {
    if (customTypes.contains(type.name))
      return isNullable ? '$data?.json' : '$data.json';
    switch (type.kind) {
      case Kind.nonNull:
        return _getSetter(
            data, type.ofType, knownTypes, customTypes, isNullable = false);
      case Kind.list:
        return '$data${isNullable ? '?' : ''}.map((_) => '
            '${_getSetter('_', type.ofType, knownTypes, customTypes)})'
            '.toList()';
      case Kind.enum_:
        return isNullable ? '$data?.toString()' : '$data.toString()';
      case Kind.object:
      case Kind.inputObject:
      case Kind.interface:
        return isNullable ? '$data?.json' : '$data.json';
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
      var fixedName = keywords.contains(camel) ? camel + '_' : camel;
      final comment = field.description?.isNotEmpty == true
          ? field.description!
              .split('\n')
              .map((_) => '/// ${_.trim()}\n')
              .join()
          : '';
      final deprecated = field is Field && field.isDeprecated
          ? '@Deprecated(\'${field.deprecationReason}\')\n'
          : '';
      final type = _getType(field.type, knownTypes, customTypes);
      final getter =
          _getGetter('json[\'$name\']', field.type, knownTypes, customTypes);
      final completeGetter =
          '$comment$deprecated$type get $fixedName => $getter;\n';
      final setter = _getSetter('value', field.type, knownTypes, customTypes);
      final completeSetter =
          'set $fixedName($type value) => json[\'$name\'] = $setter;\n';

      return completeGetter + completeSetter;
    }).join();
  }
}

// extensions

extension StringExtentions on String {
  String capitalize() => this.isNotEmpty != true
      ? this
      : this[0].toUpperCase() + this.substring(1);
  String uncapitalize() => this.isNotEmpty != true
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
  String? get description => map['description'];
}

class Type extends Adapter {
  Type(Map<String, dynamic> map) : super(map);

  Kind get kind => getKind(map['kind']);
  Iterable<Field> get fields =>
      (map['fields'] as List?)?.map((_) => Field(_)) ?? [];
  Iterable<InputField> get inputFields =>
      (map['inputFields'] as List?)?.map((_) => InputField(_)) ?? [];
  Iterable<FieldType> get interfaces =>
      (map['interfaces'] as List?)?.map((_) => FieldType(_)) ?? [];
  Iterable<EnumValue> get enumValues =>
      (map['enumValues'] as List?)?.map((_) => EnumValue(_)) ?? [];
  Iterable<FieldType> get possibleTypes =>
      (map['possibleTypes'] as List?)?.map((_) => FieldType(_)) ?? [];
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
  Iterable<Arg> get args => (map['args'] as List?)?.map((_) => Arg(_)) ?? [];
  bool get isDeprecated => map['isDeprecated'];
  String? get deprecationReason => map['deprecationReason'];
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
  String? get name => map['name'];
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
