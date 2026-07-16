/// Garment types offered by the shop (French — Mali), with the default
/// measurement fields shown for each. The measurements themselves are a
/// flexible key→value map: the manager/secretary can always add custom
/// fields on top of these suggestions.
class GarmentTypes {
  GarmentTypes._();

  static const List<String> maleGarments = <String>[
    'Grand Boubou',
    'Complet normal',
    'Chemise',
    'Veste',
    'Autres',
  ];

  static const List<String> femaleGarments = <String>[
    'Robe',
    'Jupe',
    'Autres',
  ];

  static const List<String> all = <String>[
    'Grand Boubou',
    'Complet',
    'Complet normal',
    'Chemise',
    'Veste',
    'Robe',
    'Jupe',
    'Autre',
    'Autres',
  ];

  static const Map<String, List<String>> defaultFields =
      <String, List<String>>{
    'Grand Boubou': <String>[
      'LB', 'LM', 'TM', 'E', 'P (1)', 'P (2)', 'LP', 'Cou', 'Cuisse',
      'Ceinture', 'B', 'Poignet Machette', 'Manche courte', 'Avant bras',
      'HBS', 'Mollet', 'Poignet ouvert', 'LGB', 'LGM'
    ],
    'Complet normal': <String>[
      'LB', 'LM', 'TM', 'E', 'P (1)', 'P (2)', 'LP', 'Cou', 'Cuisse',
      'Ceinture', 'B', 'Poignet Machette', 'Manche courte', 'Avant bras',
      'HBS', 'Mollet', 'Poignet ouvert', 'LGB', 'LGM'
    ],
    'Complet': <String>[
      'LB', 'LM', 'TM', 'E', 'P (1)', 'P (2)', 'LP', 'Cou', 'Cuisse',
      'Ceinture', 'B', 'Poignet Machette', 'Manche courte', 'Avant bras',
      'HBS', 'Mollet', 'Poignet ouvert', 'LGB', 'LGM'
    ],
    'Chemise': <String>[
      'LB', 'LM', 'TM', 'E', 'P (1)', 'P (2)', 'LP', 'Cou', 'Cuisse',
      'Ceinture', 'B', 'Poignet Machette', 'Manche courte', 'Avant bras',
      'HBS', 'Mollet', 'Poignet ouvert', 'LGB', 'LGM'
    ],
    'Veste': <String>[
      'LB', 'LM', 'TM', 'E', 'P (1)', 'P (2)', 'P (3)', 'LP', 'Cou', 'Cuisse',
      'Ceinture', 'B', 'Poignet Machette', 'Manche courte', 'Avant bras',
      'HBS', 'Mollet', 'Poignet ouvert', 'LGB', 'LGM'
    ],
    'Autres': <String>[
      'LB', 'LM', 'TM', 'E', 'P (1)', 'P (2)', 'LP', 'Cou', 'Cuisse',
      'Ceinture', 'B', 'Poignet Machette', 'Manche courte', 'Avant bras',
      'HBS', 'Mollet', 'Poignet ouvert', 'LGB', 'LGM'
    ],
    'Autre': <String>[
      'LB', 'LM', 'TM', 'E', 'P (1)', 'P (2)', 'LP', 'Cou', 'Cuisse',
      'Ceinture', 'B', 'Poignet Machette', 'Manche courte', 'Avant bras',
      'HBS', 'Mollet', 'Poignet ouvert', 'LGB', 'LGM'
    ],
    'Robe': <String>[
      'Shoulder', 'Shoulder to under burst', 'Half cut', 'Burst', 'Tommy',
      'Waist', 'Hip', 'Arm', 'Sleeve length', 'Blouse length', 'Skirt length',
      'Full length'
    ],
    'Jupe': <String>[
      'Shoulder', 'Shoulder to under burst', 'Half cut', 'Burst', 'Tommy',
      'Waist', 'Hip', 'Arm', 'Sleeve length', 'Blouse length', 'Skirt length',
      'Full length'
    ],
  };
}
