# Déploiement de la DAO

### Principe général

1. **Deployer** déploie `DaoCore(adminAddr)`
2. **Deployer ou Admin** deploie les `extensions & adapters`
3. **Admin** appelle `DaoCore.changeSlotEntry(slot, contractAddr)`
   - association d'un contrat à un slot extensions ou adaptateurs (Core)
4. **Admin** appelle `DaoCore.changeSlotEntry(Slot.MANAGING, managingAddr)`
   - redonne la gestion des slots au contrat `Managing`
5. La DAO peut être utilisée

Ajout de membres durant le déploiement ?  
Possibilité de _batcher_ l'ajout de slot et de membres ?
