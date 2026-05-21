class MinecraftElement {
  final String name;
  final List<double> from;
  final List<double> to;
  final MinecraftRotation? rotation;
  final Map<String, MinecraftFace>? faces;

  const MinecraftElement({
    required this.name,
    required this.from,
    required this.to,
    this.rotation,
    this.faces,
  });

  factory MinecraftElement.fromJson(Map<String, dynamic> json) {
    Map<String, MinecraftFace>? faces;
    if (json['faces'] != null) {
      faces = (json['faces'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, MinecraftFace.fromJson(v as Map<String, dynamic>)),
      );
    }
    return MinecraftElement(
      name: json['name'] as String? ?? '',
      from: _parseDoubleList(json['from']),
      to: _parseDoubleList(json['to']),
      rotation: json['rotation'] != null
          ? MinecraftRotation.fromJson(json['rotation'] as Map<String, dynamic>)
          : null,
      faces: faces,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'from': from,
        'to': to,
        if (rotation != null) 'rotation': rotation!.toJson(),
        if (faces != null)
          'faces': faces!.map((k, v) => MapEntry(k, v.toJson())),
      };
}

class MinecraftRotation {
  final List<double> origin;
  final String axis;
  final double angle;

  const MinecraftRotation({
    required this.origin,
    required this.axis,
    required this.angle,
  });

  factory MinecraftRotation.fromJson(Map<String, dynamic> json) {
    return MinecraftRotation(
      origin: _parseDoubleList(json['origin']),
      axis: json['axis'] as String? ?? 'y',
      angle: (json['angle'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'origin': origin,
        'axis': axis,
        'angle': angle,
      };
}

class MinecraftFace {
  final List<int> uv;
  final String? texture;
  final int? rotation;
  final bool? cullface;

  const MinecraftFace({
    required this.uv,
    this.texture,
    this.rotation,
    this.cullface,
  });

  factory MinecraftFace.fromJson(Map<String, dynamic> json) {
    return MinecraftFace(
      uv: _parseIntList(json['uv']),
      texture: json['texture'] as String?,
      rotation: json['rotation'] as int?,
      cullface: json['cullface'] as bool?,
    );
  }

  Map<String, dynamic> toJson() => {
        'uv': uv,
        if (texture != null) 'texture': texture,
        if (rotation != null) 'rotation': rotation,
        if (cullface != null) 'cullface': cullface,
      };
}

class MinecraftBone {
  final String name;
  final List<double>? pivot;
  final List<double>? rotation;
  final List<String>? cubes;
  final List<MinecraftBone>? children;

  const MinecraftBone({
    required this.name,
    this.pivot,
    this.rotation,
    this.cubes,
    this.children,
  });

  factory MinecraftBone.fromJson(Map<String, dynamic> json) {
    return MinecraftBone(
      name: json['name'] as String? ?? '',
      pivot: json['pivot'] != null ? _parseDoubleList(json['pivot']) : null,
      rotation:
          json['rotation'] != null ? _parseDoubleList(json['rotation']) : null,
      cubes: json['cubes'] != null
          ? (json['cubes'] as List).map((e) => e.toString()).toList()
          : null,
      children: json['children'] != null
          ? (json['children'] as List)
              .map((e) => MinecraftBone.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (pivot != null) 'pivot': pivot,
        if (rotation != null) 'rotation': rotation,
        if (cubes != null) 'cubes': cubes,
        if (children != null)
          'children': children!.map((b) => b.toJson()).toList(),
      };
}

class MinecraftEntity {
  final List<MinecraftElement> elements;
  final Map<String, dynamic>? textures;
  final List<MinecraftBone>? bones;
  final String? ambientOcclusion;

  const MinecraftEntity({
    required this.elements,
    this.textures,
    this.bones,
    this.ambientOcclusion,
  });

  factory MinecraftEntity.fromJson(Map<String, dynamic> json) {
    return MinecraftEntity(
      elements: json['elements'] != null
          ? (json['elements'] as List)
              .map((e) =>
                  MinecraftElement.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
      textures: json['textures'] as Map<String, dynamic>?,
      bones: json['bones'] != null
          ? (json['bones'] as List)
              .map((b) => MinecraftBone.fromJson(b as Map<String, dynamic>))
              .toList()
          : null,
      ambientOcclusion: json['ambientocclusion'] as String? ??
          json['ambientOcclusion'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'elements': elements.map((e) => e.toJson()).toList(),
        if (textures != null) 'textures': textures,
        if (bones != null) 'bones': bones!.map((b) => b.toJson()).toList(),
        if (ambientOcclusion != null) 'ambientocclusion': ambientOcclusion,
      };
}

List<double> _parseDoubleList(dynamic value) {
  if (value == null) return [0.0, 0.0, 0.0];
  return (value as List).map((e) => (e as num).toDouble()).toList();
}

List<int> _parseIntList(dynamic value) {
  if (value == null) return [0, 0, 0, 0];
  return (value as List).map((e) => (e as num).toInt()).toList();
}
