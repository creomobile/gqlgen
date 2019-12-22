import 'package:build/build.dart';
import 'package:gql_generator/src/graphql_generator.dart';
import 'package:source_gen/source_gen.dart';

Builder createBuilder(BuilderOptions options) =>
    SharedPartBuilder([GraphQLGenerator()], 'graphql_generator');
