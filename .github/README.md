<div align="center">

## System monet / waluta serwerowa

<img src="https://github.com/AMXX4u/money-system/blob/main/assets/_impoart_dd2_money.png?raw=true"></img>

</div>

<p align="center">
  <a href="#requirements">Wymagania ℹ</a> ×
  <a href="#description">Opis 📄</a> ×
  <a href="#configure">Konfiguracja 🛠</a>
</p>

---

### Description 
- System monet, oparty na bazie danych (MySQL),
- System posiada cvary, dzięki czemu możemy edytować ilość zdobywanych punktów przez graczy,
- Do systemu specjalnie na okazje udostępnienia, dopisałem kilka linijek, tak, aby każdy mógł korzystać, a nie osoby, które kupiły od nas VIP'a.

### Configure
<details>
  <summary><b>system.cfg</b></summary>

```cfg
amxx4u_money_host "localhost"
amxx4u_money_user "user"
amxx4u_money_pass "pass"
amxx4u_money_data "data"

amxx4u_money_kill "1"
// .description = "Ile monet za zabojstwo"

amxx4u_money_kill_hs "2"
// .description = "Ile monet za zabojstwo HS"

amxx4u_money_kill_vip "3"
// .description = "Ile monet za zabojstwo dla VIPA"

amxx4u_money_kill_hs_vip "3"
// .description = "Ile monet za zabojstwo HS dla VIPA"

amxx4u_money_planted "1"
// .description = "Ile monet za podlozenie bomby"

amxx4u_money_planted_vip "2"
// .description = "Ile monet za podlozenie bomby dla VIPA"

amxx4u_money_defused "1"
// .description = "Ile monet za rozbrojenie bomby"

amxx4u_money_defused_vip "2"
// .description = "Ile monet za rozbrojenie bomby dla VIPA"
```

</details>

### Requirements 
- AMXModX 1.9 / AMXModX 1.10
- ReHLDS 3.12.0.780
- ReAPI 5.22.0.254
- ReGameDLL 5.21.0.556
