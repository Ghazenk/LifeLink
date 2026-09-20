// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_lab_result.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetLocalLabResultCollection on Isar {
  IsarCollection<LocalLabResult> get localLabResults => this.collection();
}

const LocalLabResultSchema = CollectionSchema(
  name: r'LocalLabResult',
  id: 2389617819519830092,
  properties: {
    r'conductedBy': PropertySchema(
      id: 0,
      name: r'conductedBy',
      type: IsarType.string,
    ),
    r'hemoglobin': PropertySchema(
      id: 1,
      name: r'hemoglobin',
      type: IsarType.double,
    ),
    r'id': PropertySchema(id: 2, name: r'id', type: IsarType.string),
    r'platelets': PropertySchema(
      id: 3,
      name: r'platelets',
      type: IsarType.double,
    ),
    r'prescribedVolumeMl': PropertySchema(
      id: 4,
      name: r'prescribedVolumeMl',
      type: IsarType.long,
    ),
    r'syncStatus': PropertySchema(
      id: 5,
      name: r'syncStatus',
      type: IsarType.byte,
      enumMap: _LocalLabResultsyncStatusEnumValueMap,
    ),
    r'visitId': PropertySchema(id: 6, name: r'visitId', type: IsarType.string),
    r'wbc': PropertySchema(id: 7, name: r'wbc', type: IsarType.double),
  },

  estimateSize: _localLabResultEstimateSize,
  serialize: _localLabResultSerialize,
  deserialize: _localLabResultDeserialize,
  deserializeProp: _localLabResultDeserializeProp,
  idName: r'isarId',
  indexes: {
    r'id': IndexSchema(
      id: -3268401673993471357,
      name: r'id',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'id',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'visitId': IndexSchema(
      id: -214845532434906064,
      name: r'visitId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'visitId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _localLabResultGetId,
  getLinks: _localLabResultGetLinks,
  attach: _localLabResultAttach,
  version: '3.3.2',
);

int _localLabResultEstimateSize(
  LocalLabResult object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.conductedBy.length * 3;
  bytesCount += 3 + object.id.length * 3;
  bytesCount += 3 + object.visitId.length * 3;
  return bytesCount;
}

void _localLabResultSerialize(
  LocalLabResult object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.conductedBy);
  writer.writeDouble(offsets[1], object.hemoglobin);
  writer.writeString(offsets[2], object.id);
  writer.writeDouble(offsets[3], object.platelets);
  writer.writeLong(offsets[4], object.prescribedVolumeMl);
  writer.writeByte(offsets[5], object.syncStatus.index);
  writer.writeString(offsets[6], object.visitId);
  writer.writeDouble(offsets[7], object.wbc);
}

LocalLabResult _localLabResultDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = LocalLabResult();
  object.conductedBy = reader.readString(offsets[0]);
  object.hemoglobin = reader.readDouble(offsets[1]);
  object.id = reader.readString(offsets[2]);
  object.isarId = id;
  object.platelets = reader.readDouble(offsets[3]);
  object.prescribedVolumeMl = reader.readLongOrNull(offsets[4]);
  object.syncStatus =
      _LocalLabResultsyncStatusValueEnumMap[reader.readByteOrNull(
        offsets[5],
      )] ??
      LabResultSyncStatus.synced;
  object.visitId = reader.readString(offsets[6]);
  object.wbc = reader.readDouble(offsets[7]);
  return object;
}

P _localLabResultDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readDouble(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readDouble(offset)) as P;
    case 4:
      return (reader.readLongOrNull(offset)) as P;
    case 5:
      return (_LocalLabResultsyncStatusValueEnumMap[reader.readByteOrNull(
                offset,
              )] ??
              LabResultSyncStatus.synced)
          as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readDouble(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _LocalLabResultsyncStatusEnumValueMap = {
  'synced': 0,
  'pendingInsert': 1,
  'pendingUpdate': 2,
};
const _LocalLabResultsyncStatusValueEnumMap = {
  0: LabResultSyncStatus.synced,
  1: LabResultSyncStatus.pendingInsert,
  2: LabResultSyncStatus.pendingUpdate,
};

Id _localLabResultGetId(LocalLabResult object) {
  return object.isarId;
}

List<IsarLinkBase<dynamic>> _localLabResultGetLinks(LocalLabResult object) {
  return [];
}

void _localLabResultAttach(
  IsarCollection<dynamic> col,
  Id id,
  LocalLabResult object,
) {
  object.isarId = id;
}

extension LocalLabResultByIndex on IsarCollection<LocalLabResult> {
  Future<LocalLabResult?> getById(String id) {
    return getByIndex(r'id', [id]);
  }

  LocalLabResult? getByIdSync(String id) {
    return getByIndexSync(r'id', [id]);
  }

  Future<bool> deleteById(String id) {
    return deleteByIndex(r'id', [id]);
  }

  bool deleteByIdSync(String id) {
    return deleteByIndexSync(r'id', [id]);
  }

  Future<List<LocalLabResult?>> getAllById(List<String> idValues) {
    final values = idValues.map((e) => [e]).toList();
    return getAllByIndex(r'id', values);
  }

  List<LocalLabResult?> getAllByIdSync(List<String> idValues) {
    final values = idValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'id', values);
  }

  Future<int> deleteAllById(List<String> idValues) {
    final values = idValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'id', values);
  }

  int deleteAllByIdSync(List<String> idValues) {
    final values = idValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'id', values);
  }

  Future<Id> putById(LocalLabResult object) {
    return putByIndex(r'id', object);
  }

  Id putByIdSync(LocalLabResult object, {bool saveLinks = true}) {
    return putByIndexSync(r'id', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllById(List<LocalLabResult> objects) {
    return putAllByIndex(r'id', objects);
  }

  List<Id> putAllByIdSync(
    List<LocalLabResult> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'id', objects, saveLinks: saveLinks);
  }
}

extension LocalLabResultQueryWhereSort
    on QueryBuilder<LocalLabResult, LocalLabResult, QWhere> {
  QueryBuilder<LocalLabResult, LocalLabResult, QAfterWhere> anyIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension LocalLabResultQueryWhere
    on QueryBuilder<LocalLabResult, LocalLabResult, QWhereClause> {
  QueryBuilder<LocalLabResult, LocalLabResult, QAfterWhereClause> isarIdEqualTo(
    Id isarId,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(lower: isarId, upper: isarId),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterWhereClause>
  isarIdNotEqualTo(Id isarId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: isarId, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: isarId, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: isarId, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: isarId, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterWhereClause>
  isarIdGreaterThan(Id isarId, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: isarId, includeLower: include),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterWhereClause>
  isarIdLessThan(Id isarId, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: isarId, includeUpper: include),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterWhereClause> isarIdBetween(
    Id lowerIsarId,
    Id upperIsarId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerIsarId,
          includeLower: includeLower,
          upper: upperIsarId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterWhereClause> idEqualTo(
    String id,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'id', value: [id]),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterWhereClause> idNotEqualTo(
    String id,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'id',
                lower: [],
                upper: [id],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'id',
                lower: [id],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'id',
                lower: [id],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'id',
                lower: [],
                upper: [id],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterWhereClause>
  visitIdEqualTo(String visitId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'visitId', value: [visitId]),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterWhereClause>
  visitIdNotEqualTo(String visitId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'visitId',
                lower: [],
                upper: [visitId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'visitId',
                lower: [visitId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'visitId',
                lower: [visitId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'visitId',
                lower: [],
                upper: [visitId],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension LocalLabResultQueryFilter
    on QueryBuilder<LocalLabResult, LocalLabResult, QFilterCondition> {
  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  conductedByEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'conductedBy',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  conductedByGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'conductedBy',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  conductedByLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'conductedBy',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  conductedByBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'conductedBy',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  conductedByStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'conductedBy',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  conductedByEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'conductedBy',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  conductedByContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'conductedBy',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  conductedByMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'conductedBy',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  conductedByIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'conductedBy', value: ''),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  conductedByIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'conductedBy', value: ''),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  hemoglobinEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'hemoglobin',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  hemoglobinGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'hemoglobin',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  hemoglobinLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'hemoglobin',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  hemoglobinBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'hemoglobin',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition> idEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  idGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  idLessThan(String value, {bool include = false, bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition> idBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  idStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  idEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  idContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition> idMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  idIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: ''),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  idIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'id', value: ''),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  isarIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isarId', value: value),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  isarIdGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'isarId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  isarIdLessThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'isarId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  isarIdBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'isarId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  plateletsEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'platelets',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  plateletsGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'platelets',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  plateletsLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'platelets',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  plateletsBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'platelets',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  prescribedVolumeMlIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'prescribedVolumeMl'),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  prescribedVolumeMlIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'prescribedVolumeMl'),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  prescribedVolumeMlEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'prescribedVolumeMl', value: value),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  prescribedVolumeMlGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'prescribedVolumeMl',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  prescribedVolumeMlLessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'prescribedVolumeMl',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  prescribedVolumeMlBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'prescribedVolumeMl',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  syncStatusEqualTo(LabResultSyncStatus value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'syncStatus', value: value),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  syncStatusGreaterThan(LabResultSyncStatus value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'syncStatus',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  syncStatusLessThan(LabResultSyncStatus value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'syncStatus',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  syncStatusBetween(
    LabResultSyncStatus lower,
    LabResultSyncStatus upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'syncStatus',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  visitIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'visitId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  visitIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'visitId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  visitIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'visitId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  visitIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'visitId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  visitIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'visitId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  visitIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'visitId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  visitIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'visitId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  visitIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'visitId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  visitIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'visitId', value: ''),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  visitIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'visitId', value: ''),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  wbcEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'wbc',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  wbcGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'wbc',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  wbcLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'wbc',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterFilterCondition>
  wbcBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'wbc',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }
}

extension LocalLabResultQueryObject
    on QueryBuilder<LocalLabResult, LocalLabResult, QFilterCondition> {}

extension LocalLabResultQueryLinks
    on QueryBuilder<LocalLabResult, LocalLabResult, QFilterCondition> {}

extension LocalLabResultQuerySortBy
    on QueryBuilder<LocalLabResult, LocalLabResult, QSortBy> {
  QueryBuilder<LocalLabResult, LocalLabResult, QAfterSortBy>
  sortByConductedBy() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conductedBy', Sort.asc);
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterSortBy>
  sortByConductedByDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conductedBy', Sort.desc);
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterSortBy>
  sortByHemoglobin() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hemoglobin', Sort.asc);
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterSortBy>
  sortByHemoglobinDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hemoglobin', Sort.desc);
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterSortBy> sortById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterSortBy> sortByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterSortBy> sortByPlatelets() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'platelets', Sort.asc);
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterSortBy>
  sortByPlateletsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'platelets', Sort.desc);
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterSortBy>
  sortByPrescribedVolumeMl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'prescribedVolumeMl', Sort.asc);
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterSortBy>
  sortByPrescribedVolumeMlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'prescribedVolumeMl', Sort.desc);
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterSortBy>
  sortBySyncStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncStatus', Sort.asc);
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterSortBy>
  sortBySyncStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncStatus', Sort.desc);
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterSortBy> sortByVisitId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'visitId', Sort.asc);
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterSortBy>
  sortByVisitIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'visitId', Sort.desc);
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterSortBy> sortByWbc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'wbc', Sort.asc);
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterSortBy> sortByWbcDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'wbc', Sort.desc);
    });
  }
}

extension LocalLabResultQuerySortThenBy
    on QueryBuilder<LocalLabResult, LocalLabResult, QSortThenBy> {
  QueryBuilder<LocalLabResult, LocalLabResult, QAfterSortBy>
  thenByConductedBy() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conductedBy', Sort.asc);
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterSortBy>
  thenByConductedByDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'conductedBy', Sort.desc);
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterSortBy>
  thenByHemoglobin() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hemoglobin', Sort.asc);
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterSortBy>
  thenByHemoglobinDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hemoglobin', Sort.desc);
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterSortBy> thenByIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isarId', Sort.asc);
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterSortBy>
  thenByIsarIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isarId', Sort.desc);
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterSortBy> thenByPlatelets() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'platelets', Sort.asc);
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterSortBy>
  thenByPlateletsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'platelets', Sort.desc);
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterSortBy>
  thenByPrescribedVolumeMl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'prescribedVolumeMl', Sort.asc);
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterSortBy>
  thenByPrescribedVolumeMlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'prescribedVolumeMl', Sort.desc);
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterSortBy>
  thenBySyncStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncStatus', Sort.asc);
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterSortBy>
  thenBySyncStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncStatus', Sort.desc);
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterSortBy> thenByVisitId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'visitId', Sort.asc);
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterSortBy>
  thenByVisitIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'visitId', Sort.desc);
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterSortBy> thenByWbc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'wbc', Sort.asc);
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QAfterSortBy> thenByWbcDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'wbc', Sort.desc);
    });
  }
}

extension LocalLabResultQueryWhereDistinct
    on QueryBuilder<LocalLabResult, LocalLabResult, QDistinct> {
  QueryBuilder<LocalLabResult, LocalLabResult, QDistinct>
  distinctByConductedBy({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'conductedBy', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QDistinct>
  distinctByHemoglobin() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'hemoglobin');
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QDistinct> distinctById({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QDistinct>
  distinctByPlatelets() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'platelets');
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QDistinct>
  distinctByPrescribedVolumeMl() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'prescribedVolumeMl');
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QDistinct>
  distinctBySyncStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'syncStatus');
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QDistinct> distinctByVisitId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'visitId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalLabResult, LocalLabResult, QDistinct> distinctByWbc() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'wbc');
    });
  }
}

extension LocalLabResultQueryProperty
    on QueryBuilder<LocalLabResult, LocalLabResult, QQueryProperty> {
  QueryBuilder<LocalLabResult, int, QQueryOperations> isarIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isarId');
    });
  }

  QueryBuilder<LocalLabResult, String, QQueryOperations> conductedByProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'conductedBy');
    });
  }

  QueryBuilder<LocalLabResult, double, QQueryOperations> hemoglobinProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'hemoglobin');
    });
  }

  QueryBuilder<LocalLabResult, String, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<LocalLabResult, double, QQueryOperations> plateletsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'platelets');
    });
  }

  QueryBuilder<LocalLabResult, int?, QQueryOperations>
  prescribedVolumeMlProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'prescribedVolumeMl');
    });
  }

  QueryBuilder<LocalLabResult, LabResultSyncStatus, QQueryOperations>
  syncStatusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'syncStatus');
    });
  }

  QueryBuilder<LocalLabResult, String, QQueryOperations> visitIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'visitId');
    });
  }

  QueryBuilder<LocalLabResult, double, QQueryOperations> wbcProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'wbc');
    });
  }
}
