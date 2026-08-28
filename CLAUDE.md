# Prunay — instructions pour les agents

Simulateur de rentabilité d'un investissement locatif. Rails 8, Ruby 3.3, PostgreSQL,
Hotwire, Devise, RSpec, Docker.

**Le domaine se lit dans le [README](README.md)** — ce qui existe, pourquoi, et comment
chaque calcul est posé. Le lire avant de toucher au calcul, à la projection ou à la
fiscalité. Ce fichier-ci ne porte que les conventions de travail.

> Le README est la référence sur les règles, pas toujours sur les noms : quelques
> constantes ont déménagé depuis (`Loan::PAYMENT_DAY`, `Simulation::Step::NAMES`). Vérifier
> dans le code avant de citer un nom.

## Ce qui prime sur les règles générales

Ce projet est personnel et n'a rien d'Azure DevOps. Les règles de `~/.claude/CLAUDE.md` qui
ne s'appliquent **pas** ici :

- pas de ticket ADO, pas de PR, pas de convention de branche `feature/`/`task/` ;
- la branche principale est `main`, pas `develop` ;
- pas d'équipe d'agents imposée : le travail se fait directement, sauf demande contraire.

## Commandes

```bash
docker compose up                                     # démarrer (http://localhost:3001)
docker compose run --rm web bundle exec rspec         # toute la suite
docker compose run --rm web bundle exec rspec spec/models/projection_spec.rb:42
docker compose run --rm web rails db:prepare db:test:prepare
```

**La validation, c'est la suite RSpec au vert.** Il n'y a pas de linter : ne pas en ajouter,
ne pas inventer de commande de build.

## Conventions de code

### Les langues
- Identifiants, noms de fichiers, descriptions de specs (`it "..."`) : **anglais**.
- Commentaires et libellés d'interface : **français**.
- Aucun texte visible en dur : tout passe par `config/locales/fr.yml`.

### Les commentaires
Ils disent la règle métier ou le pourquoi d'une décision, jamais la mécanique du code.
Trois lignes en tête d'une classe pour dire ce qu'elle représente et ce qui vit ailleurs,
une ligne ailleurs, rien du tout quand le code se lit seul. Style du reste du fichier :
une phrase, pas une étiquette.

### L'argent et les taux
`BigDecimal` partout. `.to_d` sur toute entrée dans un constructeur — un taux entier ferait
une division entière et un prêt à 3 % ne coûterait rien. `.round(2)` sur les montants rendus.

### Ce qui est dérivé ne se stocke pas
Frais de notaire, capital emprunté, mensualité, tableau d'amortissement, projection, impôt :
tous recalculés. N'ajouter une colonne que pour une réponse que l'utilisateur donne lui-même.

### Où vivent les choses
- `Simulation`, `User`, `EconomicConditions` : les seuls ActiveRecord.
- `Loan`, `AmortizationSchedule`, `Projection`, `Taxation::*`, `Simulation::Estimate`,
  `Simulation::Step` : des objets simples, hors base, chacun responsable d'un calcul.
- Une constante vit sur l'objet qu'elle concerne (`Loan::DEFAULT_RATE`,
  `Projection::HORIZON_YEARS`, `Taxation::SOCIAL_CHARGES_RATE`).
- Les contextes de validation de `Simulation` portent le nom des pages de création
  (`Simulation::Step::NAMES`) : une page de plus s'ajoute là **et** dans les validations.

### Un nom sert plusieurs fois
Un onglet de la fiche est à la fois le nom du partiel, la clé de traduction, l'identifiant du
panneau et le paramètre `?tab=`. Même chose pour un régime fiscal (`Taxation::NAMES`) et pour
une page de création. Renommer, c'est renommer partout — vérifier avant de conclure.

### Les tests
- La factory `:simulation` est **neutre** : taux à zéro, charges à zéro, douze mois loués. Un
  test qui parle d'évolution énonce lui-même ses taux ; les autres n'ont pas à s'en défendre.
- Les exemples sont chiffrés et vérifiables à la main, avec un commentaire français qui
  rappelle la règle testée.
- Tout changement de calcul se prouve par un exemple chiffré, pas par un `be_positive`.

## Ce qu'on ne fait pas

- Pas de dépendance nouvelle sans le dire d'abord.
- Pas d'abstraction spéculative ni de refonte non demandée : on implémente ce qui est demandé.
- Pas de colonne pour ce qui se calcule, pas de commentaire pour ce qui se lit.
