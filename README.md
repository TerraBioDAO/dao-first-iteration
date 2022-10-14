# TerraBio DAO


## Workflows

Le *workflows* permet de voir le coverage des tests, les tests permettent d'écrire le *workflows*.

`Contrat.fonction(paramêtres)`

1. **Personnage** fait `Action`
    - changements d'état de la DAO (Core ou extensions)
    - ...
    - ...

### Entrée dans la DAO

1. **User** appelle `Onboarding.joinDao()`
    - User obtient le status de **Membre** (Core)
    - Le nombre total de membres augmente

### Déploiement de la DAO

1. **Deployer** déploie `DaoCore(adminAddr)`
2. **Deployer ou Admin** deploie les `extensions & adapters`
3. **Admin** appelle `DaoCore.changeSlotEntry(slot, contractAddr)`
    - association d'un contrat à un slot extensions ou adaptateurs (Core)
4. **Admin** appelle `DaoCore.changeSlotEntry(Slot.MANAGING, managingAddr)`
    - redonne la gestion des slots au contrat `Managing`
5. La DAO peut être utilisée

Ajout de membres durant le déploiement ?  
Possibilité de *batcher* l'ajout de slot et de membres ?