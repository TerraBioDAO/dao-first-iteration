# Unit testing

_Les workflows peuvent être décrit ici_

## Static analysis: Slither

[Docs](https://github.com/crytic/slither)

```
apt install python3-pip
pip3 install slither-analyzer
pip3 install solc-select
solc-select install 0.8.17
solc-select use 0.8.17
```

**Analyze:**

```
slither src/core/DaoCore.sol
```

---

## Workflows

Le _workflows_ permet de voir le coverage des tests, les tests permettent d'écrire le _workflows_.

`Contrat.fonction(paramêtres)`

1. **Personnage** fait `Action`
   - changements d'état de la DAO (Core ou extensions)
   - ...
   - ...

### Entrée dans la DAO

1. **User** appelle `Onboarding.joinDao()`
   - User obtient le status de **Membre** (Core)
   - Le nombre total de membres augmente
