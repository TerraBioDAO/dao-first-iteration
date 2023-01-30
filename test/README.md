# Unit testing



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

