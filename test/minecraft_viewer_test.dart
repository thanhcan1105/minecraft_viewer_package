import 'package:flutter_test/flutter_test.dart';
import 'package:minecraft_viewer/minecraft_viewer.dart';

void main() {
  group('MinecraftElement', () {
    test('fromJson parses name, from, to', () {
      final el = MinecraftElement.fromJson({
        'name': 'head',
        'from': [4.0, 24.0, 4.0],
        'to': [12.0, 32.0, 12.0],
      });
      expect(el.name, 'head');
      expect(el.from, [4.0, 24.0, 4.0]);
      expect(el.to, [12.0, 32.0, 12.0]);
      expect(el.rotation, isNull);
    });

    test('fromJson parses rotation', () {
      final el = MinecraftElement.fromJson({
        'name': 'arm',
        'from': [0.0, 0.0, 0.0],
        'to': [4.0, 12.0, 4.0],
        'rotation': {'origin': [8.0, 8.0, 8.0], 'axis': 'z', 'angle': 45.0},
      });
      expect(el.rotation, isNotNull);
      expect(el.rotation!.axis, 'z');
      expect(el.rotation!.angle, 45.0);
    });

    test('toJson round-trips cleanly', () {
      const original = MinecraftElement(
        name: 'cube',
        from: [0, 0, 0],
        to: [16, 16, 16],
      );
      final restored = MinecraftElement.fromJson(original.toJson());
      expect(restored.name, original.name);
      expect(restored.from, original.from);
      expect(restored.to, original.to);
    });
  });

  group('MinecraftRotation', () {
    test('fromJson parses all fields', () {
      final r = MinecraftRotation.fromJson({
        'origin': [8.0, 8.0, 8.0],
        'axis': 'y',
        'angle': 22.5,
      });
      expect(r.origin, [8.0, 8.0, 8.0]);
      expect(r.axis, 'y');
      expect(r.angle, 22.5);
    });

    test('defaults to y-axis angle 0 when fields missing', () {
      final r = MinecraftRotation.fromJson({
        'origin': [0.0, 0.0, 0.0],
      });
      expect(r.axis, 'y');
      expect(r.angle, 0.0);
    });
  });

  group('MinecraftFace', () {
    test('fromJson parses uv and texture', () {
      final f = MinecraftFace.fromJson({
        'uv': [0, 0, 8, 8],
        'texture': '#0',
      });
      expect(f.uv, [0, 0, 8, 8]);
      expect(f.texture, '#0');
    });
  });

  group('MinecraftEntity', () {
    test('fromJson parses elements list', () {
      final entity = MinecraftEntity.fromJson({
        'elements': [
          {'name': 'a', 'from': [0.0, 0.0, 0.0], 'to': [8.0, 8.0, 8.0]},
          {'name': 'b', 'from': [8.0, 0.0, 0.0], 'to': [16.0, 8.0, 8.0]},
        ],
      });
      expect(entity.elements.length, 2);
      expect(entity.elements[0].name, 'a');
      expect(entity.elements[1].name, 'b');
    });

    test('fromJson returns empty elements list when key absent', () {
      final entity = MinecraftEntity.fromJson({});
      expect(entity.elements, isEmpty);
    });

    test('toJson / fromJson round-trip preserves data', () {
      const original = MinecraftEntity(
        elements: [
          MinecraftElement(name: 'test', from: [1, 2, 3], to: [4, 5, 6]),
        ],
        textures: {'0': 'skin.png'},
      );
      final restored = MinecraftEntity.fromJson(original.toJson());
      expect(restored.elements.length, 1);
      expect(restored.elements[0].name, 'test');
      expect(restored.textures, {'0': 'skin.png'});
    });
  });

  group('MinecraftUtils', () {
    test('createSimpleCube produces a valid entity', () {
      final entity = MinecraftUtils.createSimpleCube();
      expect(entity.elements.length, 1);
      expect(MinecraftUtils.isValidEntity(entity.toJson()), isTrue);
    });

    test('createSimpleCube respects custom size', () {
      final entity = MinecraftUtils.createSimpleCube(size: 8);
      final el = entity.elements.first;
      expect(el.to[0] - el.from[0], 8.0);
    });

    test('createSteveModel has 6 elements', () {
      expect(MinecraftUtils.createSteveModel().elements.length, 6);
    });

    test('createCreeperModel has 6 elements', () {
      expect(MinecraftUtils.createCreeperModel().elements.length, 6);
    });

    test('getEntityBounds returns correct min/max', () {
      const entity = MinecraftEntity(
        elements: [
          MinecraftElement(name: 't', from: [2, 4, 6], to: [10, 12, 14]),
        ],
      );
      final b = MinecraftUtils.getEntityBounds(entity);
      expect(b, [2.0, 4.0, 6.0, 10.0, 12.0, 14.0]);
    });

    test('getEntityBounds handles multiple elements', () {
      const entity = MinecraftEntity(
        elements: [
          MinecraftElement(name: 'a', from: [0, 0, 0], to: [8, 8, 8]),
          MinecraftElement(name: 'b', from: [4, 0, 0], to: [16, 16, 16]),
        ],
      );
      final b = MinecraftUtils.getEntityBounds(entity);
      expect(b[0], 0.0);
      expect(b[3], 16.0);
    });

    test('getEntityCenter returns midpoint', () {
      const entity = MinecraftEntity(
        elements: [
          MinecraftElement(name: 't', from: [0, 0, 0], to: [16, 16, 16]),
        ],
      );
      expect(MinecraftUtils.getEntityCenter(entity), [8.0, 8.0, 8.0]);
    });

    test('scaleEntity multiplies coordinates', () {
      final base = MinecraftUtils.createSimpleCube();
      final scaled = MinecraftUtils.scaleEntity(base, 2.0);
      expect(scaled.elements[0].from[0],
          closeTo(base.elements[0].from[0] * 2, 0.001));
    });

    test('cloneEntity produces independent copy', () {
      final original = MinecraftUtils.createSteveModel();
      final clone = MinecraftUtils.cloneEntity(original);
      expect(clone.elements.length, original.elements.length);
      expect(identical(clone, original), isFalse);
    });

    test('mergeEntities combines all elements', () {
      final a = MinecraftUtils.createSimpleCube(name: 'a');
      final b = MinecraftUtils.createSimpleCube(name: 'b');
      final merged = MinecraftUtils.mergeEntities([a, b]);
      expect(merged.elements.length, 2);
    });

    test('isValidEntity returns false for empty map', () {
      expect(MinecraftUtils.isValidEntity({}), isFalse);
    });

    test('isValidEntity returns false when elements is not a list', () {
      expect(MinecraftUtils.isValidEntity({'elements': 'wrong'}), isFalse);
    });

    test('isValidEntity returns false for element missing from/to', () {
      expect(MinecraftUtils.isValidEntity({
        'elements': [{'name': 'oops'}],
      }), isFalse);
    });

    test('parseEntity round-trips via JSON string', () {
      const json =
          '{"elements":[{"name":"test","from":[0,0,0],"to":[16,16,16]}]}';
      final entity = MinecraftUtils.parseEntity(json);
      expect(entity.elements.length, 1);
      expect(entity.elements[0].name, 'test');
    });

    test('entityToJson produces parseable string', () {
      final entity = MinecraftUtils.createSteveModel();
      final jsonStr = MinecraftUtils.entityToJson(entity);
      final restored = MinecraftUtils.parseEntity(jsonStr);
      expect(restored.elements.length, entity.elements.length);
    });
  });
}
