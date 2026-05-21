import 'dart:convert';

import '../models/minecraft_entity.dart';

class MinecraftUtils {
  MinecraftUtils._();

  static MinecraftEntity parseEntity(String jsonString) {
    final map = jsonDecode(jsonString) as Map<String, dynamic>;
    return parseEntityFromMap(map);
  }

  static MinecraftEntity parseEntityFromMap(Map<String, dynamic> json) {
    return MinecraftEntity.fromJson(json);
  }

  static String entityToJson(MinecraftEntity entity) {
    return jsonEncode(entity.toJson());
  }

  static MinecraftEntity createSimpleCube({
    String name = 'cube',
    double size = 16.0,
  }) {
    final half = size / 2;
    return MinecraftEntity(
      elements: [
        MinecraftElement(
          name: name,
          from: [8 - half, 8 - half, 8 - half],
          to: [8 + half, 8 + half, 8 + half],
        ),
      ],
    );
  }

  static MinecraftEntity createSteveModel() {
    return const MinecraftEntity(
      elements: [
        MinecraftElement(name: 'head', from: [4, 24, 4], to: [12, 32, 12]),
        MinecraftElement(name: 'body', from: [4, 12, 5], to: [12, 24, 11]),
        MinecraftElement(name: 'right_arm', from: [0, 12, 5], to: [4, 24, 9]),
        MinecraftElement(name: 'left_arm', from: [12, 12, 5], to: [16, 24, 9]),
        MinecraftElement(name: 'right_leg', from: [4, 0, 5], to: [8, 12, 9]),
        MinecraftElement(name: 'left_leg', from: [8, 0, 5], to: [12, 12, 9]),
      ],
    );
  }

  static MinecraftEntity createCreeperModel() {
    return const MinecraftEntity(
      elements: [
        MinecraftElement(name: 'head', from: [4, 18, 4], to: [12, 26, 12]),
        MinecraftElement(name: 'body', from: [5, 6, 5], to: [11, 18, 11]),
        MinecraftElement(
            name: 'front_left_leg', from: [5, 0, 4], to: [9, 6, 8]),
        MinecraftElement(
            name: 'front_right_leg', from: [7, 0, 4], to: [11, 6, 8]),
        MinecraftElement(
            name: 'back_left_leg', from: [5, 0, 8], to: [9, 6, 12]),
        MinecraftElement(
            name: 'back_right_leg', from: [7, 0, 8], to: [11, 6, 12]),
      ],
    );
  }

  static List<double> getEntityBounds(MinecraftEntity entity) {
    if (entity.elements.isEmpty) return [0, 0, 0, 0, 0, 0];

    double minX = double.infinity,
        minY = double.infinity,
        minZ = double.infinity;
    double maxX = double.negativeInfinity,
        maxY = double.negativeInfinity,
        maxZ = double.negativeInfinity;

    for (final el in entity.elements) {
      for (final v in [el.from[0], el.to[0]]) {
        if (v < minX) minX = v;
        if (v > maxX) maxX = v;
      }
      for (final v in [el.from[1], el.to[1]]) {
        if (v < minY) minY = v;
        if (v > maxY) maxY = v;
      }
      for (final v in [el.from[2], el.to[2]]) {
        if (v < minZ) minZ = v;
        if (v > maxZ) maxZ = v;
      }
    }

    return [minX, minY, minZ, maxX, maxY, maxZ];
  }

  static List<double> getEntityCenter(MinecraftEntity entity) {
    final b = getEntityBounds(entity);
    return [(b[0] + b[3]) / 2, (b[1] + b[4]) / 2, (b[2] + b[5]) / 2];
  }

  static MinecraftEntity scaleEntity(MinecraftEntity entity, double scale) {
    return MinecraftEntity(
      elements: entity.elements
          .map((el) => MinecraftElement(
                name: el.name,
                from: el.from.map((v) => v * scale).toList(),
                to: el.to.map((v) => v * scale).toList(),
                rotation: el.rotation,
                faces: el.faces,
              ))
          .toList(),
      textures: entity.textures,
      bones: entity.bones,
      ambientOcclusion: entity.ambientOcclusion,
    );
  }

  static MinecraftEntity cloneEntity(MinecraftEntity entity) {
    return MinecraftEntity.fromJson(entity.toJson());
  }

  static MinecraftEntity mergeEntities(List<MinecraftEntity> entities) {
    final allElements = <MinecraftElement>[];
    Map<String, dynamic>? mergedTextures;

    for (final entity in entities) {
      allElements.addAll(entity.elements);
      if (entity.textures != null) {
        mergedTextures = {...?mergedTextures, ...entity.textures!};
      }
    }

    return MinecraftEntity(elements: allElements, textures: mergedTextures);
  }

  static bool isValidEntity(Map<String, dynamic> json) {
    try {
      if (!json.containsKey('elements')) return false;
      final elements = json['elements'];
      if (elements is! List) return false;
      for (final el in elements) {
        if (el is! Map) return false;
        if (!el.containsKey('from') || !el.containsKey('to')) return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
