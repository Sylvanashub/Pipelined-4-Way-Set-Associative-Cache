# Pipelined 4-Way Set-Associative Cache

---

## Design Specifications

---

**pipelined, 4-way, set-associative cache** with the following specifications:

- 2-stage pipelined (more on this later):

  - 1 cycle latency in response on cache hits
  - 1 read access per cycle throughput on cache hits
  - 0.5 write access per cycle throughput on cache hits

- 16 sets

- 4 ways per set

- 32 byte cachelines

- Write-back with a write allocate policy

- Pseudo-LRU replacement policy from lecture (Tree-PLRU)

- Indexing scheme:

  ![image-20241227115633493](https://raw.githubusercontent.com/Sylvanashub/sylvanashub.github.io/main/img/202412271202962.png)

For the pseudo-LRU policy, do not give invalid cachelines priority over whichever cacheline the PLRU logic indicates. That is, the cache must always use PLRU to decide which way to populate/invalidate.

---

### Cache Timing

![image-20241227120313943](C:\Users\pinxuw\AppData\Roaming\Typora\typora-user-images\image-20241227120313943.png)

### Clean Misses

![image-20241227115904908](https://raw.githubusercontent.com/Sylvanashub/sylvanashub.github.io/main/img/202412271202965.png)