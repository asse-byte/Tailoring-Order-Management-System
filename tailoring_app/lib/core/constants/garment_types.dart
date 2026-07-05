/// Garment types offered by the shop (French — Mali), with the default
/// measurement fields shown for each. The measurements themselves are a
/// flexible key→value map: the manager/secretary can always add custom
/// fields on top of these suggestions.
class GarmentTypes {
  GarmentTypes._();

  static const List<String> all = <String>[
    'Boubou',
    'Complet',
    'Chemise',
    'Pantalon',
    'Robe',
    'Jupe',
    'Veste',
    'Autre',
  ];

  static const Map<String, List<String>> defaultFields =
      <String, List<String>>{
    'Boubou': <String>[
      'Épaule', 'Poitrine', 'Longueur totale', 'Longueur manche',
      'Tour de cou', 'Poignet',
    ],
    'Complet': <String>[
      'Épaule', 'Poitrine', 'Taille', 'Longueur veste', 'Longueur manche',
      'Tour de cou', 'Ceinture', 'Cuisse', 'Longueur pantalon', 'Bas pantalon',
    ],
    'Chemise': <String>[
      'Épaule', 'Poitrine', 'Taille', 'Longueur', 'Longueur manche',
      'Tour de cou', 'Poignet',
    ],
    'Pantalon': <String>[
      'Ceinture', 'Bassin', 'Cuisse', 'Genou', 'Bas', 'Longueur',
    ],
    'Robe': <String>[
      'Épaule', 'Poitrine', 'Taille', 'Bassin', 'Longueur', 'Longueur manche',
    ],
    'Jupe': <String>['Ceinture', 'Bassin', 'Longueur'],
    'Veste': <String>[
      'Épaule', 'Poitrine', 'Taille', 'Longueur', 'Longueur manche',
    ],
    'Autre': <String>[],
  };
}
