# Spec — l'amortissement du LMNP tel que le fisc l'attend

Source : « Comment fonctionne l'amortissement en LMNP ? » (BailFacile, `lmnp-amortissement.pdf`),
confronté à ce que Prunay fait aujourd'hui dans `Taxation::Lmnp`, `Projection` et
`Taxation::CapitalGain`.

## 1. Ce que Prunay fait aujourd'hui, et ce qui manque

Aujourd'hui le LMNP amortit **80 % du prix payé sur 25 ans**, à plat, et rien d'autre. L'excédent
d'une année ne passe pas à la suivante. La revente réintègre tout ce qui a été amorti.

Ce que le PDF décrit et que Prunay ignore :

| Règle réelle | Prunay aujourd'hui |
|:---|:---|
| Un plan **par composant** : bâti, mobilier, travaux, chacun avec sa durée | Une seule ligne, le bâti |
| La part du **terrain** (10 à 20 %) n'est jamais amortie | 20 %, sans nuance |
| Les **frais d'acquisition** (notaire) s'amortissent quand le bien est loué dès l'achat | Ignorés |
| Les **travaux d'amélioration** s'amortissent | Ignorés |
| Le **mobilier** s'amortit | Ignoré, alors que la colonne `furniture` existe |
| L'amortissement **ne peut pas créer de déficit** : il se déduit dans la limite du résultat avant amortissement | Idem, mais l'excédent est perdu |
| L'excédent **se reporte sans limite de durée** (art. 39 C CGI) | Rien ne se reporte |
| **Prorata temporis** la première année | Sans objet, voir § 2.6 |

Un point où le PDF est **dépassé** : il affirme que la plus-value « ne tient pas compte des
amortissements pratiqués ». C'était vrai avant la loi de finances 2025 ; depuis, les
amortissements déduits sont réintégrés dans la plus-value. Prunay le fait déjà et **continue de le
faire** — la spec ne suit pas le PDF sur ce point, elle précise seulement *quels* amortissements
reviennent (§ 2.5).

## 2. Les règles retenues

### 2.1 Les composants et leur base

Trois composants, tous amortis linéairement depuis la première année louée :

| Composant | Base amortissable | Ce que Prunay a déjà |
|:---|:---|:---|
| **Bâti** | (prix d'achat + frais de notaire) × (1 − part du terrain) | `purchase_price`, `notary_fees` |
| **Travaux** | les travaux initiaux | `initial_works` |
| **Mobilier** | les meubles achetés à la signature | `furniture` |

Les frais de notaire suivent le bâti : en pratique ils se répartissent sur tous les composants
au prorata, terrain compris, et la part du terrain ne s'amortit pas — d'où le facteur unique
(1 − part du terrain) sur prix et frais ensemble. La condition du PDF (« mis en location
rapidement après l'achat ») est toujours remplie dans Prunay : la première année est louée.

**Aucun paramètre nouveau à saisir.** Tout est déjà dans la simulation.

### 2.2 Les hypothèses chiffrées

Le PDF donne des fourchettes ; on prend le milieu, arrondi à l'année entière inférieure quand il
tombe sur une demie — un plan se compte en années pleines, et la durée la plus courte est celle
que le comptable choisit.

| Hypothèse | Fourchette du PDF | Retenu | Constante |
|:---|:---|:---|:---|
| Part du terrain | 10 à 20 % | **15 %** | `DepreciationPlan::LAND_SHARE = 0.15` |
| Durée du bâti | 25 à 40 ans | **32 ans** | `COMPONENTS[:building] = 32` |
| Durée des travaux | 5 ans (sol) à 20 ans (électricité) | **12 ans** | `COMPONENTS[:works] = 12` |
| Durée du mobilier | 5 à 10 ans | **7 ans** | `COMPONENTS[:furniture] = 7` |

Chaque valeur est une constante : si l'on préfère les 30 ans des exemples du PDF pour le bâti,
c'est un chiffre à changer et les specs qui le citent.

### 2.3 L'annuité

```
annuité = (base / durée).round(2)          pour les années 1 à durée − 1
dernière annuité = base − (durée − 1) × annuité   (le plan solde exactement la base)
```

Rien l'année 0 (le jour de l'achat), rien après la dernière année du plan. Le bâti à 32 ans court
au-delà des 30 ans de la projection : sa dernière annuité n'apparaît jamais.

### 2.4 Le plafond et le report (art. 39 C)

C'est le changement de fond. Chaque année :

```
résultat avant amortissement = max(recettes − charges − charges propres − intérêts, 0)
amortissement disponible     = annuités du plan de l'année + report des années précédentes
amortissement déduit         = min(disponible, résultat avant amortissement)
report vers l'année suivante = disponible − déduit
revenu imposable             = résultat avant amortissement − déduit
```

Le report est **sans limite de durée** et **ne s'éteint qu'avec la revente** — Prunay ne simule
pas la revente comme une fin de régime, le stock reporté est simplement affiché et perdu l'année
où l'on vend.

**Ordre d'imputation.** Le déduit se répartit entre les composants dans l'ordre **bâti, travaux,
mobilier**, chacun jusqu'à épuisement de son disponible (annuité + son propre report). Cet ordre
n'est pas dans la loi, qui raisonne en masse : c'est un choix de Prunay, nécessaire parce que
seul le bâti revient dans la plus-value (§ 2.5). Il est prudent — il réintègre le plus possible —
et vérifiable à la main. L'alternative serait un prorata ; on ne la retient pas.

Conséquence : le report se tient **par composant**, un `Hash` `{ building:, works:, furniture: }`
que la projection passe d'une année à la suivante, exactement comme elle cumule déjà les
amortissements pour la plus-value.

### 2.5 Ce que la revente réintègre

La loi de finances 2025 réintègre les amortissements **déduits** — pas ceux simplement inscrits —
et en exclut ceux qui correspondent aux dépenses de travaux (art. 150 VB II 4°, déjà couvertes par
le forfait de 15 % que Prunay applique). Le mobilier, bien meuble, ne participe pas à une
plus-value immobilière.

Donc : `CapitalGain#depreciation` reçoit le **cumul du bâti effectivement déduit** jusqu'à
l'année de vente, et rien d'autre. Ce qui est encore en report ne revient pas.

### 2.6 Ce qui reste hors périmètre, et pourquoi

- **Le prorata temporis.** Les années de Prunay sont des anniversaires de l'achat, douze mois
  pleins chacune : il n'y a pas de première année partielle. Sans objet.
- **Le seuil de 600 €** au-dessous duquel un meuble passe en charge. Prunay a un budget meubles
  global, pas un inventaire. On amortit tout.
- **Le renouvellement du mobilier** après 7 ans. `furniture_maintenance`, charge de l'année,
  en tient lieu. Un plan qui repartirait à zéro serait une seconde itération.
- **Le déficit hors amortissement** (charges + intérêts > recettes), reportable dix ans sur les
  BIC non professionnels. Ce n'est pas l'amortissement : on garde le comportement actuel (une
  année sans résultat ne doit rien, rien ne passe). À noter comme suite possible : la mécanique
  du report écrite ici s'y prête.
- **Une part de terrain selon le type de bien** (une maison a plus de terrain qu'un
  appartement). Une constante d'abord ; un `Hash` par `PROPERTY_TYPES` si le besoin se fait sentir.

## 3. Conception

### 3.1 `Taxation::DepreciationPlan` — nouveau, hors base

Le plan d'amortissement d'une simulation : ses bases, ses annuités, et ce que chaque année
inscrit. Pur, sans état, comme `Loan` ou `SaleCosts`.

```ruby
module Taxation
  class DepreciationPlan
    LAND_SHARE = BigDecimal("0.15")
    # L'ordre est celui de l'imputation (voir Lmnp) : le bâti d'abord, seul à revenir dans la plus-value.
    COMPONENTS = { building: 32, works: 12, furniture: 7 }.freeze

    def initialize(price:, acquisition_fees:, works:, furniture:)   # .to_d partout

    def bases            # => { building: 184_120.20, works: 12_000, furniture: 2_100 }
    def annuity(component)
    def lines(year)      # => les annuités de l'année, sans les zéros ; {} pour l'année 0 et hors plan
    def total(year)
  end
end
```

`Simulation#depreciation_plan` le construit :
`DepreciationPlan.new(price: purchase_price, acquisition_fees: notary_fees, works: initial_works, furniture: furniture)`.

### 3.2 `Taxation::Regime` et `Taxation::Lmnp`

Le régime ne calcule plus le plan ; il reçoit les annuités de l'année et le report entrant, et
rend ce qu'il déduit et ce qu'il reporte.

- `Regime#initialize` : **ajoute** `depreciation: {}` (les lignes du plan pour l'année) et
  `deferred_depreciation: {}` (le report entrant, par composant) ; **retire** `purchase_price:`
  et `year:`, qui ne servaient qu'à l'ancien calcul. `attr_reader` pour les deux nouveaux.
- `Regime` (défauts, tous régimes sauf LMNP) : `depreciation = 0`,
  `deducted_depreciation_lines = {}`, `carried_forward_depreciation = {}`.
- `Lmnp` :

```ruby
DEPRECIATED_SHARE et DEPRECIATION_YEARS disparaissent (ils vivent dans DepreciationPlan).

def result_before_depreciation = [receipts - charges - own_charges - loan_interest, 0].max

# Annuité + report, composant par composant.
def available_depreciation

# Impute dans l'ordre de DepreciationPlan::COMPONENTS jusqu'au plafond.
def deducted_depreciation_lines

def depreciation = deducted_depreciation_lines.values.sum

# Ce que l'année suivante recevra en deferred_depreciation:, sans les zéros.
def carried_forward_depreciation

def taxable_income = result_before_depreciation - depreciation
```

### 3.3 `Simulation#taxation` et `Projection`

- `Simulation#taxation(regime, ..., depreciation: depreciation_plan.lines(year), deferred_depreciation: {}, year: 1)`
  — `year` reste un argument de la méthode pour choisir les lignes du plan, mais n'est plus
  transmis au régime. `purchase_price` ne l'est plus non plus.
- `Projection#build_years` porte deux accumulateurs au lieu d'un :
  - `deferred = {}` — passé à `taxation_for`, puis remplacé par `taxation.carried_forward_depreciation` ;
  - `cumulative_depreciation += taxation.deducted_depreciation_lines.fetch(:building, 0)` — ce qui
    part dans `capital_gain_taxation(..., depreciation:)`. Le commentaire existant (« l'année en
    cours en fait partie ») reste vrai.
- `Projection#taxation_for` gagne `deferred` et `number` sert à `depreciation_plan.lines(number)`.
- `CapitalGain` : **inchangé**. Il reçoit déjà un cumul et le retranche de la valeur d'acquisition.

### 3.4 Les autres régimes

Rien ne change pour le micro-foncier, le foncier réel et le micro-BIC : ils gardent les défauts de
`Regime`. `Taxation::Bic` ne bouge pas.

## 4. Affichage

### 4.1 Le détail de l'impôt d'une année (`SimulationsHelper#tax_detail_lines`)

Aujourd'hui une ligne « Amortissement du bâti ». Demain, entre les recettes et le revenu
imposable, dans cet ordre et sans les lignes à zéro :

| Ligne | Signe | Source |
|:---|:---|:---|
| Amortissement du bâti | − | `depreciation_lines[:building]` |
| Amortissement des travaux | − | `depreciation_lines[:works]` |
| Amortissement des meubles | − | `depreciation_lines[:furniture]` |
| Amortissements reportés des années précédentes | − | somme de `deferred_depreciation` |
| Excédent d'amortissement reporté | + | somme de `carried_forward_depreciation` |

La somme des cinq vaut `−depreciation`, ce qui est déduit : la règle « les lignes du détail
somment sur la ligne parente » tient. La condition d'affichage devient
`taxable_income.positive? || available_depreciation.positive?` — une année qui reporte tout a
quelque chose à dire même sans impôt.

Clés à ajouter dans `fr.yml`, la clé `detail_depreciation` renommée :
`detail_depreciation_building`, `detail_depreciation_works`, `detail_depreciation_furniture`,
`detail_deferred_depreciation`, `detail_carried_forward_depreciation`. Les libellés ci-dessus.

Le détail de la plus-value garde sa ligne « Amortissements réintégrés » : elle ne porte plus que le
bâti déduit, le libellé reste juste.

### 4.2 L'onglet paramètres : le plan

Un bloc « Plan d'amortissement », visible sous le seul LMNP (`hidden` + `data-regimes="lmnp"`,
comme le comptable), à la suite des charges du régime. Le tableau du PDF, une ligne par composant
dont la base n'est pas nulle :

| Composant | Base | Durée | Annuité |
|:---|---:|---:|---:|
| Bâti (85 % du prix et des frais de notaire) | 184 120,20 € | 32 ans | 5 753,76 € |
| Travaux | 12 000,00 € | 12 ans | 1 000,00 € |
| Meubles | 2 100,00 € | 7 ans | 300,00 € |

Partiel `simulations/_depreciation_plan.html.erb`, clés `views.simulations.show.depreciation_plan_*`.
Rien dans la barre de synthèse ni dans le cash-flow : l'amortissement ne décaisse rien, il ne
paraît que dans le détail de l'impôt et dans ce tableau.

## 5. Les exemples chiffrés

### 5.1 Le plan (spec de `DepreciationPlan`)

Prix 200 000 €, frais de notaire 16 612 €, travaux 12 000 €, meubles 2 100 €.

- Terrain : 216 612 × 15 % = 32 491,80 €. Base du bâti : **184 120,20 €**.
- Annuité du bâti : 184 120,20 / 32 = 5 753,75625 → **5 753,76 €** ; année 32 : 184 120,20 − 31 × 5 753,76 = 5 753,64 €.
- Travaux : **1 000 €** par an, années 1 à 12 ; 0 en année 13.
- Meubles : **300 €** par an, années 1 à 7 ; 0 en année 8.
- `lines(1)` = `{ building: 5_753.76, works: 1_000, furniture: 300 }`, `total(1)` = 7 053,76 €.
- `lines(0)` = `{}`. Sans travaux ni meubles, `lines(1)` n'a que le bâti.

### 5.2 Le plafond et le report (spec de `Lmnp`)

Le régime reçoit ses lignes en dur : `depreciation: { building: 6_000, works: 1_000, furniture: 300 }`,
recettes 13 200 €, charges 2 000 €, charges propres 1 200 € (CFE 300, meubles 400, comptable 500).

- **Sans intérêts** : résultat avant amortissement 10 000 €, tout se déduit (7 300 €), imposable
  2 700 €, rien ne se reporte.
- **5 000 € d'intérêts** : résultat 5 000 €. Déduit : bâti 5 000, travaux 0, meubles 0.
  Reporté : `{ building: 1_000, works: 1_000, furniture: 300 }`. Imposable 0, impôt 0.
- **L'année d'après**, mêmes lignes et `deferred_depreciation: { building: 1_000, works: 1_000, furniture: 300 }`,
  intérêts 4 000 € : résultat 6 000 €, disponible bâti 7 000. Déduit : bâti 6 000, rien d'autre.
  Reporté : `{ building: 1_000, works: 2_000, furniture: 600 }` — le stock grossit tant que le
  résultat ne dépasse pas l'annuité.
- **Une année confortable**, intérêts 0, même report entrant : résultat 10 000 €, disponible
  9 600 €, tout se déduit, imposable 400 €, report vide.

### 5.3 La projection (spec de `Projection`, fabrique neutre : 800 € de loyer, comptable 500 €)

Loyers LMNP 10 080 €, CFE 252 €, comptable 500 € : résultat avant amortissement **9 328 €**.
Le plan n'a que le bâti, 5 753,76 € par an (frais de notaire 16 612 €, ni travaux ni meubles).

- Année 1 : déduit 5 753,76 €, imposable **3 574,24 €**, prélèvements sociaux 18,6 % → **664,81 €**.
  Cash-flow 10 080 − 752 − 664,81 = **8 663,19 €**.
- Année 30 : le plan court toujours (32 ans) ; l'exemple « le plan s'éteint après 25 ans »
  disparaît, remplacé par « déduit encore la trentième année ».
- Revente année 5 : réintégration 5 × 5 753,76 = **28 768,80 €**, valeur fiscale
  216 612 − 28 768,80 = 187 843,20 €, plus-value sur un bien vendu à son prix **12 156,80 €**.
- Avec crédit (`:with_credit`, 193 224 € à 3 % sur 20 ans) : la première année les intérêts
  avalent le résultat, le bâti est déduit partiellement, le report est non vide et
  `years[1].gain.depreciation` vaut le seul bâti déduit, pas l'annuité. Un test montre
  que le report est bien consommé une année où les intérêts ont baissé.
- Avec `furniture: 2_100, initial_works: 12_000` : `charge_lines` ne change pas (l'amortissement
  n'est pas une charge), le détail de l'impôt porte trois lignes.

### 5.4 Les requêtes (`spec/requests/simulations_spec.rb`)

La fiche de l'année 1 du LMNP montre les lignes du § 4.1 avec les montants du § 5.3 ; le
paramétrage montre le tableau du § 4.2 sous le seul LMNP.

## 6. Ce qui change dans les tests existants

| Spec | Aujourd'hui | Après |
|:---|:---|:---|
| `lmnp_spec` `#depreciation` | 6 400 €, constantes 0,80 / 25 | Remplacé par § 5.2 ; les constantes sont testées dans `depreciation_plan_spec` |
| `lmnp_spec` `attributes` | `purchase_price:`, `year:` | `depreciation: {...}` |
| `projection_spec` LMNP année 1 | 6 400 / 2 928 / 544,61 | 5 753,76 / 3 574,24 / 664,81 |
| `projection_spec` cash-flow | 8 783,39 | 8 663,19 |
| `projection_spec` « plan over » années 25/26 | 544,61 / 1 735,01 | supprimé, voir § 5.3 |
| `projection_spec` revente année 5 | 32 000 / 15 388 / 5 570,46 | 28 768,80 / 12 156,80 / 4 400,76 |
| `projection_spec` « no more than the plan » 160 000 | | supprimé : le plan ne s'éteint plus dans l'horizon |
| `requests` détail LMNP −6 400 | | −5 753,76 sous la nouvelle clé |
| `capital_gain_spec` | | inchangé |

## 7. Découpage en commits

Chacun laisse la suite au vert.

1. **`Taxation::DepreciationPlan`** et sa spec (§ 5.1). Rien ne l'appelle encore.
2. **Le régime et la projection** : `Regime`/`Lmnp` (§ 3.2), `Simulation#taxation` et
   `Projection` (§ 3.3), réintégration du seul bâti déduit ; specs `lmnp`, `projection`,
   `simulation` mises à jour (§ 5.2, 5.3, 6).
3. **La fiche** : lignes du détail de l'impôt et locales (§ 4.1), tableau du plan (§ 4.2),
   specs de requêtes (§ 5.4).
4. **README** : le paragraphe du LMNP (plan par composant, plafond, report) et celui de la
   plus-value (seul le bâti déduit revient) ; la note de `CLAUDE.md` sur les constantes qui
   ont déménagé peut citer `Taxation::DepreciationPlan`.

## 8. À trancher avant de coder

Tout a une valeur par défaut ci-dessus ; ce sont les trois choix qui méritent un regard :

1. **32 ans pour le bâti** (milieu de la fourchette) ou **30 ans** (les exemples du PDF, et
   l'horizon de la projection) ? Une constante.
2. **Bâti d'abord** dans l'imputation (prudent, réintègre le plus) ou **prorata** ? § 2.4.
3. **Le déficit hors amortissement** : on le laisse perdu comme aujourd'hui, ou on ouvre une
   seconde itération pour le reporter dix ans ? § 2.6.
