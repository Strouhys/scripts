Příprava prostředí HR a VODWH-20260803_090159-Záznam schůzky
3. srpna 2026, 7:02dop.
50 min 57 s

Strouhal Jiří zahájil(a) přepis

Mluvčí 1   0:05
Tak tmavě.

Strouhal Jiří   0:07
Tak podívám se pojď.

Mluvčí 1   0:08
Asi jo.
Hele.
Počkej, jak já se vezmu s green?
Nejsem nějak extra připravenej, ale pokusím se jo.
A tak.
1 poznatek je ten.
Že.
Máme.
Různý repozitáře, který jsou k dispozici jo.
Ukazuji tech dokument, kterej je v hlavním repu VONDP repozitáři, je to pod architekturou, jmenuje se git repositories.
A odkazuju se teď tady na tu tabulku.
A my vlastně dneska máme připravenej stage inges pro RDV.
A máme ještě 2 další vertikály, které se musí postavit 1 je HR, což jsou o two školy data, ale jsou nějakou formou citliví a záměrně stojí bokem v bigquery. To je jiný projekt.
AV dvh, což nejsou útučkový data a my je nevlastníme. Jenom je zpracováváme a je to tím pádem jakoby taky jinej projekt jo, takže máme vlastně 3 projekty po two CZEPOCZEP je ten kterej jakoby pro nás asi nejvíc důležitej, to jsou naše outúčkový data, pak máme Outlook CZHP, což jsou taky naše data, ale jsou citliví, je to HR, takže to stojí bokem.
A pak máme VODVH, který stojí úplně bokem, protože to nejsou naše data, jo.
A vlastně tadyhle ten split přes ty 3 vertikály se bude odrážet přes celou infrastrukturu, kterou tam máme a přes všechny depozitáře, který tam máme čili pro stageový ing přes extraktový loady. Jsou to tyhle ty 3 data jo.
Všechny 3 existujou, ale pouze e pouze EDV repozitory je osídlený.
HRAVODVH osídlený ještě nejsou VODVH jsem začal osidlovat dneska ráno jako vzor před asi 5 minutama mám to rozdělaný, můžu ukázat co mám a můžu popsat, co je potřeba. Ještě doděláte nějak jako se to pokusit předat.
Jo.
Takže 1 věc, kterou je potřeba udělat, tak je vlastně osídlit a začal bych asi od od VODVH prostě. O co myslíš?

Levíček Rostislav   2:25
Ne, já jsem chtěl začít od HRZ toho důvodu, že na čtyřista trojce jo, protože.

Mluvčí 1   2:27
Poté dobrý.
Tak, já já mám nějak rozvrtaný VODVH tak commitnu pusnu a pak pak na základě toho je možné to vzít jako vzor a udělat na základě toho HR jo. Takže tohle je to repo, na který by se to mělo asi jako soustředit tím pádem.

Levíček Rostislav   2:31
To.
Jo.

Mluvčí 1   2:41
Jo, to je to, co je potřeba nachystat udělat.
Tak takže to je to je 1 důležitej poznatek asi teda sem dám do chatu.
Možná bokem začnu psát nějaký linky.
A referencované zdroje.

Levíček Rostislav   2:58
Jo čili jirko 1 krok nebo 1. Z kroků, který budeme dělat, je, že budeme muset dotáhnout to repozitory, z kterýho se o tom bude vlastně nasazovat.
Pro agenda.

Mluvčí 1   3:10
Tak jo.

Strouhal Jiří   3:11
Jasně, to znamená vlastně by udělat obdobu nebo skoro stejnou strukturu, jak máme pro é DV.

Levíček Rostislav   3:18
Jo.

Mluvčí 1   3:19
Ano.
Popíšu ve větším detailu jo.
Tam by rovnou něco tady udělat, ale nebudu to jako úplně dotahovat. Jo a možná bych radši comitnul to VODVHA odešel od toho, protože tam mám nějaký PR nad produkci, takže a času málo dneska.

Levíček Rostislav   3:40
Jo.

Mluvčí 1   3:42
Tak.
2 poznatek je popis, který říká, co je vlastně nastavené, jak na těch serverech, respektive na tom serveru. Jo, bavíme se o entimepo 403, to je tenhle ten dokument.
A takže nastavení pro NT info 4 0 3 tak.
A já tady teď nechci procházet, ale v podstatě v podstatě. Podle něj je potřeba to udělat AV principu. Jde o to, že je potřeba udělat klon.
Toho VODV ne VODVHR repa.
Dělat klon HR repozitory.
A zkontrolovat nastavení.
Uvnitř toho repozitory.

Levíček Rostislav   4:34
To znamená klon na 400 trojku.

Strouhal Jiří   4:36
To znamená.

Mluvčí 1   4:37
Ano.

Levíček Rostislav   4:37
Jako nejdřív se postaví to repo v tom gitu, pak se odklonuje na 400 trojku a je potřeba ho zkontrolovat. Bude to ve stejným adresáři.

Mluvčí 1   4:40
Ano a to se odklonuje na 400 trojku.
Tohle je vlastně příprava přípravná fáze.

Levíček Rostislav   4:48
Jako.

Mluvčí 1   4:51
Ano ano ve stejném adresáři, ale on ten adresář má taky nějakou strukturu. Já tady teď mám připojenej.
Připojenej tam disk.
Minutku 400 trojka i vypadá to tam nějak takhle? Tohle je i disk na 400 trojce.
Adresáři DP se vlastně objevuje celá stage že jo a tady v tý složce jsou ty depository jako samostatný podsložky, takže tady se objeví nová podsložka.

Levíček Rostislav   5:11
Ano.
Ano.
Ano.

Mluvčí 1   5:20
Která bude držet cafu, říká VODVH, ale myslím HR jo, tak pardon bude obsahovat to HR depo a paralelně. Vedle toho se objeví datová složka pro to AR depo ta se musí založit a musí se vlastně osídlit toho adresářovou strukturu, která tady pod tím je a vzhledem k těch složek je tam poměrně dost, tak já to teď jako nebudu tady nějak dělat, tvrdí. Nebo on možná, že bych mohl dělat tree tadyhle?

Strouhal Jiří   5:24
Jasný.

Levíček Rostislav   5:25
Jo jo jasný.

Strouhal Jiří   5:31
Aha.

Levíček Rostislav   5:41
Jo.

Mluvčí 1   5:45
A takhle možná rvali já moc jo level.

Strouhal Jiří   5:47
Jasný takže ty ty ty složky musejí mít vlastně i oprávnění na na na ty vlastně by na ty účty na ty SP admi nebo já teďka nevím jak to máme pojmenovaný. Já se podívám na to mám tady uložený.

Mluvčí 1   5:50
Jo.

Levíček Rostislav   5:53
Jo.

Mluvčí 1   5:54
Ano.

Strouhal Jiří   6:03
To, co jsme vlastně my dělali předtím, dá se říct.

Levíček Rostislav   6:07
Ano tam je jediný rozdíl, je to úplně stejný jako ta stage, to znamená, postaví se to úplně stejně jako ta EP stage. Bude to prostě vedle toho druhej druhej klon a jenom.

Mluvčí 1   6:08
Ano.

Levíček Rostislav   6:22
V nějakým bodě je potřeba u toho HR?
Omezit nebo vyjmenovat.
Já nevím, jestli do toho mají přístup. View teďkon vývojáři. Myslím si, že mají.

Strouhal Jiří   6:34
Myslím že ne no.

Levíček Rostislav   6:37
Nemaj.

Strouhal Jiří   6:38
Já jsem to ověřoval, já jsem ověřoval s Tomášem, jestli se dostane do složky, kde máme ten Jason pro.
Pro vlastně by bicquery a nedostane se tam.

Levíček Rostislav   6:51
Jo, to je dobře, ale tady ještě takový vo omezení, že u toho HR by neměli mít vývojáři přístup na source files.
To znamená místo kam?

Mluvčí 1   7:02
Protéká to přes tu datovou složku. Kyp se vlastně dostáváme k té adresářové struktuře. Jak já tady udělám znova ten tree moment?
Tak.
1 tak tohle, to je vlastně ta adresářová struktura pod tím.
Teď mám ho tady HP jo a protéká to vlastně tadyhle přes ten adresář, takže tady je potřeba nastavit práva tak, aby se k tomu.
Nedostali vývojáři.

Levíček Rostislav   7:44
Tak a jako.

Mluvčí 1   7:44
Kromě skupiny a teď nevim, jaká je ta skupina jo.

Levíček Rostislav   7:47
Age.
No developers HR.

Strouhal Jiří   7:49
No a tam jsme jakoby no no no.

Levíček Rostislav   7:53
Na ty skupiny byly na té 40 trojce. Já nevím jak je to teď, ale když tak se tam podívám. Jo, ale byly nastavený tak, že existovala skupina o two developers, o two developers AO two developers HRA ty množiny byly disumní, to znamená, že ti co byli VHR nebyli v tom developers jo, to je z toho důvodu, že.
Windows mají takovou vlastnost, že když nastavuješ oprávnění a dáš tam 2.
Skupiny tak oni berou jako lézt privileti nejnižší úroveň oprávnění, takže pakliže někdo nemá nějaký právo, tak to vyhraje nad tím, že má nějaký právo. Jo. To znamená, že kdyby kdybych dal toho vývojáře jako do 2. Skupin a ti developers neměli právo na HR, tak by se vlastně ti HR dovede přidat tam jako nedostali. Takže.
Je to postavený tak, že HR developers je malá skupina lidí, což je Michal.
Stáňa a Zdeněk Kalina, kteří mají právo vidět tu HR část a nejsou ve složce developer ve skupině developers a všude, kde jsou nastavený developers, tak tam mají IHRI ty HR developers právo.
Ale na HR složky mají právo jenom ti HR developers.

Strouhal Jiří   9:21
Enhnm.

Levíček Rostislav   9:22
Jo, takhle to bylo jako koncipovaný, když tak se tam potom spolu kouknem, nebo já to klidně donastavím. Jo tyhlencty oprávnění, nebo spíš spolu, že bychom si sedli.
A file systém ty ho připravíš a pak si projdeme oprávnění na těch složkách a jenom si potvrdíme, že to správně.

Strouhal Jiří   9:39
Jasně jo, jenom, jak jsem ještě psal, tak mám od minulého týdne problém. S tou s tím přihlášením na ty servery nevím proč mi to píše.

Levíček Rostislav   9:40
Jo.
Jasně, to musíme vyřešit, no.

Strouhal Jiří   9:51
Takže jsem hnedka ve čtvrtek založil SPP, takže čekám co mi co mi to?

Levíček Rostislav   9:56
Minuty.

Strouhal Jiří   9:58
Pošlou.
Určitě budu jasný.

Levíček Rostislav   10:04
Jo jo tak kdyžtak zajdeme za tam.
Na bezpečnost, že to potřebujem vyřešit jako urgent abys abys to prostě byla jo že si to tam zaorgujeme.

Strouhal Jiří   10:15
Jo jo super.
Já já když udělám restart 1 druhej restart, tak pak třeba se mi to jako podaří tam připojit. Jo, tak nevím proč to.

Levíček Rostislav   10:23
Jo jo jo jo.

Strouhal Jiří   10:25
Nevím.

Levíček Rostislav   10:26
Já teda jako naštěstí s tím nebojuju, ale nemám ten software rád, takže.
Takže jo, takže 1 úkol je postavit si vlastně repo pak to repo vlastně se odklonuje na 400 trojku a postaví se ta datová složka pro HP to je druhej nebo 3 úkol.

Strouhal Jiří   10:36
Ano.

Levíček Rostislav   10:49
Jo.

Mluvčí 1   10:50
Já tady já tady ještě na schůzce udělám nějakej bleskovej nástřel, jenom jako nástřel. Jo, neříkám, že to dotáhnu, ale.
Ale fakt aspoň nástřeletina co navázat jo.

Levíček Rostislav   10:56
A nedělaj von si to Jirka Jirka projde nebo?

Strouhal Jiří   10:59
Já se to určitě, hele.

Mluvčí 1   11:00
No tak můžem můžem taky můžem taky. Každopádně si udělám klon.

Strouhal Jiří   11:06
Takhle, čím víc to Honza udělá, tím tím líp pro mě.

Mluvčí 1   11:07
Každopádně každopádně tam založím branč. Není dobrý dělat rovnou na mainu. Jo tyhle věci všechny.
Je dobrý, je dobrý začít na developu a pak, když to je v nějakým rozumným stavu, tak to třeba macenot na main jo, ale takže tady by měla bejt.
Developeranč, která tam zatím ani neexistuje.
Na ní by se to mělo dělat, že jo.
Tak teď už existuje, vrá by se jí založil.
A to repo je prázdný, teď tam nic není. Jo jasně.
Se mi chce.
Dobrý, tak tohle nechám běžet na pozadí a zatím se teda povinnu trochu tomu, co je potřeba v tom repu udělat. Vlastně jo, tak.

Levíček Rostislav   11:50
Rovnat.

Mluvčí 1   11:52
Takže nicméně ještě ještě možná řeknu, jakoby vidím tam teda nějakou jako přípravnou fázi na tý 400 trojice, která má 2 části 1. Část je to repozitory tam dostat nějak to jako nahrubo připravit, nastavit přístupový práva, že jo viz diskuze a pak je potřeba vlastně připravit si ta scrudler tak, aby sme to pak vysokej zapnout, jo?
To jsou, to jsou zhruba ty věci. No a teď se dostáváme vlastně k tý konfiguraci, což je ta složitější část. Dostáváme se vlastně tady, z jaký části, co je potřeba tam vlastně udělat? No.
A když se podíváš na stage report, tady doleva dám stage a tady doprava dám rozdělaný VODVH, který tady mám tahle VODVH.
Tak si všimni, že ta struktura je furt stejná. Jo dags dags data data.

Strouhal Jiří   12:42
Jasně.

Mluvčí 1   12:43
Ten up jo, a když půjdeš trošku do většího detailu a začne šťourat, tak už tam jsou vidět rozdíly, tak všimni si.
Všimni si, že ta datová složka tady a ta datová složky složka tady.
Zatím nemá jiný název, ale měla by mít jinej název. Tady by to mělo bejt VODVH, takže VPV případě HR by to mělo být HP.
Jo tadytová složka by měla mít jiný název, protože to pro jinej projekt tak já tady dám ten správnej název.

Strouhal Jiří   13:04
Enhnm.

Mluvčí 1   13:11
Tahle datová složka vlastně ani není komitlá v gitu. Myslím si, že v git ignoruju jo.
Subsistery.
Tak shledáš EDV data?
Jo ano mělo by být ignorovaná, ale koukám, že v tom git ignoruju. Tady mám chybu, takže tady v git ignoru je potřeba vyignorovat tu datovou složku dělám DODVH, takže tady bude VP.

Levíček Rostislav   13:37
Odpovědět.

Strouhal Jiří   13:39
Web.

Mluvčí 1   13:41
Jo takže píšu sem opravit git ignor.
Zadat do něj.
Správný adresář pro to databu složku.
Protože když to neuděláš, tak ti tam furt. Ten lod bude generovat nějaký změny v tom repu a to repu nebude nikdy čistý. Já to nechceš? Jo, takže tady bude HP.
Pro HR.
Tak.
Založit si tam u adresářovou strukturu. Té to je vlastně založený, to je vlastně jakoby přidaný. Tady, že jo, tady vlastně zakládáš tu datovou složku a ty se musíš ujistit, že není gitovaná.
Jo, je to srozumitelný.

Strouhal Jiří   14:33
Asi jo.

Mluvčí 1   14:34
OK.

Strouhal Jiří   14:35
Ah.

Mluvčí 1   14:36
Takže ta 1 1 taková změna? Pak je potřeba vlastně řešit konfiguraci toho loadu a takže je tady v adresáři té nand jo.
Tenant je vlastně něco, co ten lot spouští, takže půjdu do taranta. Tady půjdu do taranta. Všimni si, že tady je jiný název.
Jo takže ten tenant pro HR by se měl jmenovat nějak jinak? Neměl by se jmenovat EDV? Musíme se asi dohodnout na tom názvu, protože tohle název jsme myslím zatím jako nějak nefixovali.
Právě adresář.
Ten repu 2 úroveň.
Ření.
Není PDV.
Ale něco jinýho.
Teď já nevím, co dívám se, jestli to máme. No podívám se, jestli to máme nějak popsaný, já nevím, jo, člověk si to pamatuji.

Levíček Rostislav   15:32
A pojďme se rovnou domluvit co to bude.

Mluvčí 1   15:45
Ale jo nazve ho HR.

Levíček Rostislav   15:49
Tak.

Mluvčí 1   15:50
Jo tady mám takový čehárna.
Adresář vznikne kopí.
Z repa.
PDVID.
Tooo CZPPSTGEDV.
Jo.
Takže vlastně z toho stageový data pro EDV si vezmeš tady ten adresář a hodíš si ho.
Jsem jako HR.
A když říkám jsem, já tady teď ukazuju VODVH, nebo bude to i čárový, nebo jo?

Strouhal Jiří   16:30
Jo jo.

Mluvčí 1   16:32
Všechno, co tam je, tak tam takhle naklopím. Jo tak.
No a pak je samozřejmě nutný jakoby projít si tu konfiguraci a všimni si, že ta konfigurace má 2 části a ona má dokonce 3 části tyhle 3 adresa řekněme je potřeba se nějak zabejvat. Možná že i ty skripty to nemám rozkoukaný a možná že i ten powershell to vlastně taky jako nemám rozkoukaný tím ale do detailu, no ale v principu o co jde.
Nejdůležitější jsou tady ty 2 složky.
Protože to je konfigurace toho loadu, kterou používají paktnovské skripty. AV nich se objevují věci jako název projektů, název účtu a spol. Protože je vlastně potřeba zalézt sem do tady těch 2 adresářů.
A jsou tady nějaké soubory a to je potřeba editovat, podívat se do nich a editovat. Je jo já, když vezmu třeba tady ten otevřu ho tady.

Strouhal Jiří   17:12
Enhnm.

Mluvčí 1   17:16
Podívám se co tam je.
Teď to začnu procházet a přemejšlet jo tak.
Projekt pro rezervaci slotů ten máme jenom 1, ten se nemění, takže tam nic neupravuju.
Názvy projektů, názvy bucketů, tak projekt samozřejmě nebude ED 1, ale děláme HR, takže to bude HD 1 to samý ten bucket bude HD 1.

Strouhal Jiří   17:36
Večer.
Aha.

Levíček Rostislav   17:41
Honzo máme tam ten sufix UHDAVD.

Mluvčí 1   17:45
Jakej sufix.

Levíček Rostislav   17:46
No jestli projekt je HD 1 nebo HD jenom.

Mluvčí 1   17:50
V devovém by mělo být HD 1. Já teda nevím, jestli ten projekt existuje, ale snad jo.
To je otázka na Jirku, jestli je projekt založenej nejenom mě.

Levíček Rostislav   17:58
Já já já si nejsem jistej hlavně tím sufixem. Já se na projekt podí.

Mluvčí 1   18:02
Měl by bejt stejnej to prostředí by mělo bejt nastavený identicky přes všechny prostředí, takže jako za mě je vlastně to za mě požadavek, aby existoval tady ten projekt. Jo.

Levíček Rostislav   18:12
No, já si myslím, že nemá sufix ale to je celý. Já se na to podívám.

Mluvčí 1   18:13
A tady ten bucket.
Tak se možná kouknem, jo pak jako teď nevím, tak já to vlastně zjistím a.

Levíček Rostislav   18:21
Já se dívám už.
Pak, až na něj mám právo.

Mluvčí 1   18:25
Glout.
Project list možná.

Levíček Rostislav   18:30
Hele jo.
Možná nemám totiž vůbec.
Oprávnění.

Mluvčí 1   18:49
Žádný příklad project.

Levíček Rostislav   18:51
No a.

Mluvčí 1   18:52
Člověk.

Levíček Rostislav   18:53
To název toho projektu, jestli ten vývojovej, jestli bude HD nebo HD 1.
Si řeknem s Jirkou, Jirka bude až ve čtvrtek. Jo, Jirka má dovču 3 dny.

Mluvčí 1   19:03
No dobrý, tak se ještě kouknem teda do dokumentace jo než budeme prudit Jirku podláka, protože to by mělo bejt přece popsaný resource hierarchie.
Datová platforma.
Potul CZHD 1.

Levíček Rostislav   19:22
OK tak jo.

Mluvčí 1   19:23
Dáno jo o two CZHD 1 je to daný?

Levíček Rostislav   19:26
Jo, jo, já jsem jasně v pohodě, dobrý, dobrý tím lépe.

Mluvčí 1   19:29
Jo, takže vlastně všechny tyhle ty místa, kde se objevuje EP nebo ED, tak místo toho bude HP nebo HD jo prostě přejmenovat všude konzistentně stejně na všech místech.
Název konečný to samý HD 1. Název účtu tady nevím.
Tady nevím.
Co tam má?
Ani o tom nemáš ty zanesenej.
Jo asi v exlo vlastně bude jenom 1, takže tady vlastně tady vlastně asi nic, že jo.
A.
Tohleto se asi nemění.
Jo čili čili když to, když to dá jak sesumíruju do toho textu, kterej mám teď rozdělanej, tak vlastně je potřeba jít tajdle do toho fajlu.
Vrátím se zpátky na ten popis, který píšu.
Editace konfigurace.
A takhle ne takhle ne, ale takhle jo.
Nechám tady špatnou cestu, nech toho nenechám, to bude plést, to je zase HP.
Teda page AR config de jo dobrý.
Takže mění se, mění se názvy projektů.
PD 1 ne počkej není to PD 1 je to jo vlastně jo ED 1 ED 1 se mění na HD 1 že jo?
Názvy projektů a paketů.
Se mění takhle.
Jo databáze se vedou stejně, protože ty datový sety v těch projektech jsou nazvány vždycky stejně.
Takže tohle je identický?
Mění se, mění se název konečný.
Tady jo.
Se.
Protože connec.
No.
AS je jiná.
Takže to je.
Pak je tady konfigurace of lock componenty.
V tom samém adresáři jo?
A 7.
Vypadá.
Tak tady.
Otázku, který jedou a nějaký další věci, tady bych řekl, že důležitý je hlavně pohlídat si ty názvy, jo.

Strouhal Jiří   22:09
Hm.

Mluvčí 1   22:09
Že preferoval bych aby tam kde EDV tak, aby tam bylo místo toho HR.
Jo.

Strouhal Jiří   22:15
Jasný.

Mluvčí 1   22:17
Takže konfigurační fille.
A zaměnit.
Za PHR consistentně všude.
A nastavit jiný na počet otázku.
5.
Jo.
Tady, jak často se čeká, než zkouší, jakoby najít joby, které můžou běžet. Je to 5 sekund, když to jde do failu, tak za jak dlouho se to pokusí pustit znova za 60 sekund? Jo.
Takže.
Tady jako hlavně to přejmenovat.
A.
Jo mělo by stačit, změnit tady ty názvy, protože když na když na to koukneš, tak tohle říká, do jakého filu si loguje. Tohle říká, do jakého figlu se odkládá stav, když ta komponenta jde dolů jo, takže název toho figu bude jinej a jde cit, to je všechno.

Strouhal Jiří   23:36
Peču.
Tak dál.

Mluvčí 1   23:43
Jo takže tyhle 2 filely a tohle webový load?
No a pak to samý pro produkční lou že jo.
Si koupíš na produkční load. Všimni si, že tady jinej projekt pro slot rezervaci v devu je to dvoustovka, tady je to stovka.
Ale to je 1 to je správně? No a ta úvaha je tady stejná, že jo název projektu místo EP bude HP to samý pro ty pakety to samý pro konečnu, ale ta změna je vlastně stejná.
Filozoficky stejná jsem různý.

Strouhal Jiří   24:11
Jo jo jasný.

Mluvčí 1   24:12
Jo takže to samý to samý pak vlastně proprodukční konfiguraci?
Obdobně pro.
Produkční konfiguraci, ale pochopitelně měníš produkční názvy.
Měníš.
Názvy.
Trefím vás.
Placen za.
A samozřejmě jakoby to není jenom o tady tom file, kterej jakoby konfiguruje pythonské skripty, ale pochopitelně je to i tady, že jo, tohle pak reálně pojede na produkci a tady je fakt důležitý, aby tady bylo těch 15 pásků ne 30 teda řek sem 15 myslím 5.
5 pásku ne 30 jo.
Možná by sis to chtěl pozesit, protože tady 30. Když na produkci je 15, to je, protože já jsem začal chystat tu změnu pro.

Strouhal Jiří   25:04
No.

Mluvčí 1   25:08
Psali jsme si o tom dneska ráno.

Strouhal Jiří   25:09
Na to na to IMD na to IMD.

Mluvčí 1   25:11
No, no, no, no no a teď jak jsem kopíroval aily do toho VODVH, tak mi tam vletělo 30.

Strouhal Jiří   25:16
Aha jo.

Mluvčí 1   25:18
Jo, takže to jsou tyhle 2 složky?
Konfigurace.
No a pak je ta víc záludná část, tato je tady bin.
Tady je potřeba připravit hlavně konfigurát pro vývojáře a hlavně šakovat tadyhle ty soubory jo, který jsou produkční konfigurace, tak možná že je důležitější spíš ta produkční konfigurace, protože ta reálně na tý produkci pojede. Jo jsou tady 2 baťáky, který to pouštěj, když se jdu do nich kouknem co tam je, tak budou asi poměrně chudý. Všimni si, že tady provolávaj nějakej, NA všimni si, že tady je cesta, no tak pochopitelně je potřeba zajistit, aby tady byla ta správná.
Ta cesta ne EDE, ale HR jo tohle písmenko je blbě pro HR.
Jo.
No a pak to pouští of flow, tak tady je zase musí bejt správnej a za souborů bavili jsme se o to, že to on chceme přejmenovat. ZEDV by mělo bejt HR, takže název projektu musím upravit.
Název fena musím upravit, aby se to načetlo tu konfiguraci správně a tady tady vlastně je ten adresář. Jo, tady je DV, měl by tam být HR.
Je to srozumitelný.

Strouhal Jiří   26:27
Je trošku se ztrácím ale.

Mluvčí 1   26:29
Bezva.
No kdybys to nechal tak jak to je, tak ti to vlastně pustí EDV of konfiguraci že jo a ono spadne protože ten port je obsazenej.

Strouhal Jiří   26:31
Ale to.
Jasný.

Mluvčí 1   26:42
Čili dám to zase do toho textu tady, který ti pak pošlu.

Strouhal Jiří   26:43
Jo.

Mluvčí 1   26:48
Editace a souborů, které jezdí na produkci.
Co tady bude HP?
A tady vlastně měnič EDV měníč za PR všude.
A.
Tohle.
A umění za HR.
Všude.
Jo, takže vlastně ten baťák?
Ten baťák, když se spustí, tak on se musí. On si musí provolat správnej ze správního místa. Jo, tady musí bejt správná cesta ne ED včková cesta, ale HM cesta, takže měním písmenko.
Aby to odpovídalo té adresářové struktuře, tak, jak si upravíme.
To samé tady.
Tak správně.
Tohle mi přijde trochu jako nadbytečnej řádek, když se na to teď koukám, jo.
Ale to je asi 1.

Levíček Rostislav   28:19
Klidně nerevidujme no.

Mluvčí 1   28:20
Když na to teď koukám, tak tahle cesta, tohle tohle selže jako jo tohle cesta neexistuje, ale podstatný, že tohle se spustí. Jo, vlastně je to postavený tak, že všechny proměnný prostředí, které se používají, tak se nastavujou 100 nwoo a pak se voněj ty baťáky dál opíraj.
Jo.
Takže měním vlastně tadyhle ten file, abych upravil cesty a pak je tady ještě druhej baťák, kterej pouští stageovej lot pro 1 tabulku.
Jenom 1 tabulku typicky to reprodukci neděláš, ale teoreticky jako to může být chtít někdy provést a zase stejná úprava tady změnit, změnit cesty a nechat to pak bejt.
Jo takže?
EP bude HPEDV bude HR.
Jo.
Tyhle 2 baťáky se upravuju.
Tento spouští of flow.
A.
Není důležité.
Spouští 1 load z ruky.
Nejezdí běžně lodem.
Admin zásahy.
Jo, když bych potřeboval něco jako odjet ad, hoc tak přestat ten baťák bych to dokázal udělat.
No a co je, co je jako ještě s tím souvisí, tak je vlastně tady ten, že jo, kterej na produkce se používá.
A tam vlastně tam vlastně ta konfigurace těch proměnnejch prostředí. Jo, ten je macatej, když se na ně koukneš, tak ten je fakt jako macaterej no, ale v principu fruta samá úprava. Prostě je tady potřeba změnit ty adresáře.
Všude, kde je všude, kde je tohle to repo zmíněný, tak musí být KI čárový depo a všude, kde je zmíněnej ten ank.
Trhutnej PDD tak musí bejt HR.
Jo v principu vlastně sáhneš sem.
Sáhneš sem a ten zbytek by měl zůstat víceméně stejnej. Jo, tady pak už se to opírá vod, konfigurace vesměs a je to potřeba projít. Jo to.

Strouhal Jiří   30:25
Prosím.

Mluvčí 1   30:26
Ještě potřeboval taky sáhnout.
Datová, složka.
Jo takže setn.
Vypl se do toho popisuju.
Střední.
Když teda se kouknu na to, který se takhle splýtnu, tak to je vedle toho.
Tak určitě je potřeba upravit penatname.
Určitě je potřeba upravit ten antrapoliar.

Strouhal Jiří   31:05
Jo za to asi pojedu to tam si vyhledám prostě kde jsou EPA.

Mluvčí 1   31:09
No no no, to je.
Lapade name.
Zbytek pak tady někde bude port jo, někdo tady bude port.
Tohle zatím nic, tohle nic.
Tohle je potřeba určitě upravit.
A tam si musíme říct rovnou na co? Protože to ty nebudeš vědět takhle od stolu.
A ta cesta správná je jaká.
No a.
A.
Screenshope.
S ní to je vlastně konfigurace, která zasouvá. My zpracujeme soubor a předhodíme zpátky do RDV do archivu ARD archivy se to pak po sobě uklidní, jo?
To je vlastně jakoby konfigurace tý vidličky.
No a pak tohle.
Protože tohle ti říká, na jakým portu pojede offlow a tohle tohle ti říká, na jakým portu byla webová komponenta, když bys ji měla ty produkty spuštěnou, umí ji tam, nespouštíme, spouští ji u sebe lokálně jo, ale obě ty proměny dobrý nastavit.
Takže určitě nastavit tuhle tu.
A ty porty jsou popsaný valukačním plá plánu tady.
80 10. Ruční čá r 80 20.
A webový port tuším že bude 80 82 ale kouknem se.
Tak ne tak je to 80. 12.
Jo.
70 to je nějaká nekonzistence počkej?
80, 81.

Strouhal Jiří   33:45
Není to jedenáctka.
Jo myslím že 11 honzo.

Mluvčí 1   33:49
Budem věřit, budeme věřit tomu, jak to je v kódu jo, já to tady upravím.

Strouhal Jiří   33:53
Já myslím, že jo já si to pamatuju já myslím, že to je jedenáctka.

Mluvčí 1   33:56
Jsme to nějak řešili, my jsme to nějak řešili kvůli macafee to jsme tam měli nějakej konflikt, něco nějakej problém. Já už nevím, já teď si nejsem jistej, co je správně? Popravdě jo, ale ono to tam nejede, takže?
Pak spíš jde vo to, jak si to nastavíš u sebe lokální a když budeš pouštět webovej fronta pro HRO.
Jo, protože ty máš teď připravenej webovej fronta pro é dvéčko, tak budeš potřebovat webový frontend pro HR. Tam si to nějak nastavíš tak, aby ti to jelo? Jo.

Strouhal Jiří   34:17
Hra v jasný, jasný, jasný.

Mluvčí 1   34:22
A tak.
Ne tadyhle.
Takhle to mám vysvětlený koukej.
Jo, takže macaf jí drží pod 80 81.

Strouhal Jiří   34:35
Jo, protože tam něco běželo na tom.
No.

Mluvčí 1   34:38
Tak.
Je tady ještě něco ber do toho. Ten nám dnes proměnný prostředí neřešil bych to, neřešil bych to, že se jakoby pro EDVA pro HR budem hlásit pod jiným bar toanem na of flow. Neřešil bych to, nechal bych stejnej. Máme to teď tak nastavený, máme ten bir do toho nastavenej přes proměnnou prostředí na úrovni operačního systému a nechal bych to tak? Jo, přijde mi to zbytečná komplikace.

Strouhal Jiří   34:55
Enhnm.
Jo dobře.

Mluvčí 1   35:04
Tak, takže tímhle tím vlastně jakoby nastavíš ten load tak, aby hledal ty věci na správných místech. Jelo to na správným portu, aby to celé fungovalo pro produkci pro produkci. No a pak je tam ještě devová konfigurace.
A webová konfigurace je jakoby maličko komplikovaná tím, že si jí každý ohýbá vývojář ohýbá tak, jak chce. Popravdě řečeno, tohle asi není až tak jako tvoje starost, ale já si myslím, že v rámci cvičení se na to můžeš podívat taky. A když, tak jako řekneš no pivet a nějak si to jako postavte jo.
Ale.
Tvoříme to nějakej čas, když se na to mrkneš taky, a tak tenhleten file.
Myslím že jinde jo že je neni není.
Jo vlastně v tom je taky v tom viru, stejně jako ten 100 je tak je taky v tom vinu a to je vlastně šablona, kterou si vývojáři kopírují a do který se dělají zásahy.
Šablona, když se do ní koukne.
Vypadá nějak takhle divoce? Jo, je to šablona bla bla bla bla bla a tady tady je vlastně potřeba upravit to repoze.
EP míž za HP projekt datovou složku EP míč za HP na todle není potřeba už podle mě dál sahat jo, tohle už si tohle už se pak mění i ti vývojáři sami.
Tady ti už se ti nezabýváš?
Už všechno je stejný, odvozený vlastně od.

Strouhal Jiří   36:32
Dobrá.

Mluvčí 1   36:35
Tady těch údajů.
Údajů tyhle 3 údaje roood.
Průměr data limity data věrnejma tenantname.
To jsou ty 3 věci, který se mění mezi těma vertikálama.
Jo, takže vlastně tyhle věci je potřeba projít v tom repu?
V tom HP repu měníš to v něm v develop branchi jedině to provozoval.
Změnu udělá VDVL princi.
Zatím.
A.
Případný test.
A povedeme na produkci s developerem czech, to znamená tak, jak se dělá czech tou AD paná 400 trojce, tak se to checkout developech a udělá se ten test na.
Jo.
A jde nám teď asi jako primárně o to, aby se to spustilo a aby to nic nedělo.

Strouhal Jiří   37:54
Dobře dobře samozřejmě teď.
Až to začnu rozkukávat, tak samozřejmě se budu ptát. Jo to.

Mluvčí 1   38:00
V pohodě, v pohodě. Hele, proto děláme ten záznam. Jo, proto děláme ten záznam. Proto existujou ty popisy. Klíčový dokumenty jsou vlastně.

Levíček Rostislav   38:02
To je jasný jirko.

Mluvčí 1   38:10
Tyhlety že jo tadyhle je popsaný jaký data existujou a je tam vlastně zmíněný jak jak jak vypadají ty názvy?
Pak druhej důležitej tenhle ten ten říká, jak to na ty 400 prodejce je postavený jediná odchylka UHR jsou ty práva tady že jo.

Strouhal Jiří   38:26
Hm.

Mluvčí 1   38:28
Ale jak je to to samý?
Tam není potřeba cokoliv měnit.

Strouhal Jiří   38:32
Jo.

Mluvčí 1   38:35
Vlastně celá ta konfigurace je o názvech jo a měníš měníš název repozitory.
Měníš název projektu měníš název tenhle 3 věci typicky jo stav objevu v tý konfiguraci. Ten ant není ERV, ale HR projekt je o two CZHPA ne o to CZEP no a to repo vlastně se jmenuje podle toho projektu, že jo tahleta část tady se změní písmenko ZEDV se stane HRA, to je všecko a když se to takhle korektně nastaví, tak by to pak mělo fungovat.

Strouhal Jiří   38:42
Cesty jasný.
Enhnm.
Jo jo jo.

Levíček Rostislav   39:06
Honzo.

Mluvčí 1   39:08
Ještě, když o tom mluvím, tak mi dochází.
Já tam přece jenom pošlu nějaký 1 naivní commit no.
Prostě.

Levíček Rostislav   39:16
Ale ty teď seš na VP.

Mluvčí 1   39:20
Jo já vim.
A tam přece jenom pošlu 1 naivní commit.
Protože vývojáři pak budou hledat tuhle složku a my vnímáme dneska konfiguraci generátoru, jo.
Takže já tady dělám takhle složku darks.
To umí takhle plácnu tyhle 2 fily, který tebe vlastně vůbec nezajímají. Do toho ale vývojáři vlastně potřebujou, protože přes ně generátor pak ví, kde hledat ty správný věci, tak tohle to tam ještě comitnu.

Levíček Rostislav   39:50
Hele a my jsme se i bavili vo čtyřista trojce, to znamená rozchodit, to upravit, připravit repoto je úplně 1 krok, pak to nastavit na 400 trojice co NT in fo t 404.

Mluvčí 1   39:50
P.
No nebylo by rozumný a na ní nejdřív odnést re vload.
A pak se teprve zabejvat nastavením bigwayi a 400 čtyřce.

Levíček Rostislav   40:18
Já t 404 já.

Mluvčí 1   40:19
Co.
Jo to je 404. Aha sorry tam je to docela jednoduchý, protože t čtyřista čtyřka je postavená tak.

Levíček Rostislav   40:21
O vývojovým prostředí o vývojovém sebe.

Mluvčí 1   40:31
Ona je to nastavení tý produkce jo.
A.

Levíček Rostislav   40:35
Jo.

Mluvčí 1   40:35
Když se podíváš, jak je to udělaný?

Levíček Rostislav   40:38
Já jsem si myslel, že to bude 1 Jirka dělat na t čtyřista čtyřce a my vlastně teďkon směřujeme k tomu, že to připraví na na produkci. Mě to jako nebá v zásadě.

Mluvčí 1   40:39
Tak vlastně?
Tak jako může no může.
Asi je rozumný, asi rozumný. Připravit to nepo na sucho a pak odejít na tu čtyřista čtyřku a vyzkoušet si to tam. Ano, to je asi rozumnej postup. A když se podíváš, jak je to tady udělaný, tak vlastně existuje adresář DP kořenovej, že jo stejně jako na produkci.

Levíček Rostislav   41:04
Ano.

Mluvčí 1   41:04
V něm je tahle složka, ve který je knihovna.
Kterou lot používá o tu se starám já.

Levíček Rostislav   41:12
Jo.

Mluvčí 1   41:15
A na to není potřeba sahat.
A pak vlastně každej vývojář, tady má adresář svůj.
Včetně regy strouhal a teď teda nevím, kterej je tvůj tadleten deficit AV něm je ten klon.

Strouhal Jiří   41:27
Jo jo.

Levíček Rostislav   41:29
Jo.

Mluvčí 1   41:29
Jo, takže jsem se odklunuje to repo.
A pak vlastně další krok je ten, že když to prostředí setuješ abys tam dokázal něco spustit, tak právě jdeš do adresáře tena to já ti to ukážu radši u sebe, abych Jirkovi něco nerozbil.
Nevím jakým to má Jirka stavu tady do dee PE jo můj blon.
Ten up.

Levíček Rostislav   41:50
Hm.

Mluvčí 1   41:52
A teď, abych dokázal jakoby s tím pracovat za předpokladu, že někdo připravil tyhle 2 adresáře, což udělá Jirka, tak já pak jenom jdu do adresáře bin.
A celý ten lod vlastně založený na tom principu, že tady je.
Tady je do TNF si ho tady takhle zruším jo a jenom abych o ni nepřišel a já vlastně vezmu tady ten template.
Takhle si to tady zkopíruju.

Levíček Rostislav   42:16
A ten si uděláš z toho NV ten playte.

Mluvčí 1   42:16
Se jmenuju? No, no, no přemenuju si ho.

Levíček Rostislav   42:18
Jasně.

Mluvčí 1   42:22
AV něm si změním.
Podstatné parametry a to je tohle?
Jo, takže tady musí být to moje ten můj root to moje repo, takže tady já si dám.

Levíček Rostislav   42:29
To s Jirka připraví.

Mluvčí 1   42:35
Dev JHE.

Levíček Rostislav   42:36
Jo takhle jasně jasně no.

Mluvčí 1   42:38
V polovině.

Levíček Rostislav   42:44
Hm.

Mluvčí 1   42:44
Tak.
Aport.

Levíček Rostislav   42:48
Jo.

Mluvčí 1   42:48
To je všechno, jo tady tady změním port.

Levíček Rostislav   42:49
Jo.
Jo.

Mluvčí 1   42:52
Ten zbytek je furt stejnej.

Levíček Rostislav   42:53
Dobře.
Takže to si může Jirka zkusit u sebe?

Mluvčí 1   42:55
Jo ten test té šablony, takže pro vývojáře je to vlastně úprava Dvořák? No no no no no jo a pak to musí fungovat.

Levíček Rostislav   42:59
Jo.
Jaká to může zkusit u sebe? A jako jirko jako testovacího vývojáře budeš mít potom Zdeňka kalinu.
No, já budu totiž pozdeňkovi chtít, aby ve chvíli, kdy budeme mít základ nějakej připravenej tak, aby byl ten vývojář, kterej půjde a začne brát stageový HR extrakty a bude dělat ten vývoj, protože stáňa není Michal, dělá lo GA bude mít mraky práce, takže Zdeněk bude ten, kdo vlastně převede všechny stageový ono jich není nějak extra moc HR extrakty.
A připraví to, takže on bude takovej tvůj couterpart samozřejmě.

Mluvčí 1   43:37
Jo.

Levíček Rostislav   43:38
A co budete Honzy, ale on bude ten kdo bude ověřovat, že na tom vývoji je to schopen vyvinout a tak dále.

Mluvčí 1   43:43
Lo.

Strouhal Jiří   43:46
Jo.

Mluvčí 1   43:46
HR máme připravený tady stage HR migračním repu že jo on HTP metam mig r 20% z to GBHR nikdo to nikdy nezkoušel.

Levíček Rostislav   43:52
Jasně.

Mluvčí 1   43:57
Tak já jako doufám, že tady jako zběžně mrknu, ale vypadá to na 1 dobrou rozumě. Jo, tady vidím jasný, tohle je dobrý. Tady vidím správný název projektu out CZHP.
Samý tady.
Názvy datasetu se nemění, ty jsou stejný, takže já myslím, že by to mělo jako fungovat tak, jak lidi jsou zvyklí, když se to správně nastaví, což jsme si tady teď řekli, že jo a.

Levíček Rostislav   44:21
Jo jo.

Mluvčí 1   44:21
Přemejšlím, jestli tohle soubor mám koětovat někam, nebo jestli ho jenom pošlu do teamsů? Jo, možná commit.

Levíček Rostislav   44:29
Myslíš to je teďkon ten návod pro pro.

Mluvčí 1   44:31
Tenhleten návod, no jo, takže tohle tohle nazvu to.

Strouhal Jiří   44:33
Jo jo.

Mluvčí 1   44:36
Návod na konfiguraci STG repozy.

Levíček Rostislav   44:45
Pro další vertikálu.

Mluvčí 1   44:45
Jo i.
Tento návod popisuje, co je potřeba změnit.
Při další vertikáli.

Levíček Rostislav   45:00
Holt to budem opakovat.

Mluvčí 1   45:01
A brsknu ho.

Levíček Rostislav   45:03
Zatím je pořád moje představa, že toto opakování 2 udělá Daniel, ale nejsem si tím úplně jistej, takže?

Mluvčí 1   45:09
Zrovna jsem nazvu ho.
A nová, vertikálně anglicky.
Config.
Stage repo MD jo takhle ho nazvu.

Levíček Rostislav   45:22
Hm.

Mluvčí 1   45:28
Tam tam ten text.
Šup.
Možná tady dám teda i ty linky i ty.
Co dělá.
Frekvencové zdroje.
Architektura a metadata, repositories.
A tu poklávesu zkratko 2.
A bit repositories pak jsme tam měli použitej ještě nějakej jo ten popis tý instalace.

Levíček Rostislav   46:13
Infrastructure.

Mluvčí 1   46:14
Jo jo já vím a to je vlastně na stejný úrovni.
Takže tady?
Jinak.
Je postavená produkce.
Repo.
Tak je postavený DCR.
Jo.
Cestuje, založil li sem?
Nastavením pro nábor.
Bezstage, bez stage.
Je to tam, je to pošlí na tinde commits.
Jo a je tam jenom to nastavení pro ten generátor dobře.
To je všecko.
Takže to je těžké? Kolik tod tohle?

Levíček Rostislav   47:34
Hele na biquery.
Bakety.

Mluvčí 1   47:40
To by mělo všechno bejt založený už doufám.

Levíček Rostislav   47:43
Nejsou tam nějaký, nezakládají se nějaké struktury? Všechno to jako.
Von jako Jirka bodlák samozřejmě.
I pokud že něco nezaložil, tak terafon udělá on vo tom ví, že to je priorita udělat HR jako postavit a pak udělá VODVH jenom. Jako se ptám, jestli my sme tam potom něco nezakládali mimo mimo tedafon.

Mluvčí 1   48:05
Ne už je to zakládá ta pipelina vlastně?

Levíček Rostislav   48:09
Jo.

Mluvčí 1   48:10
Pracovní tabulky se zakládá přímo ten exekutor loadu, když je potřeba, je dělat.
Datový sety musejí vzniknout, teda formu backety musí vzniknout teda formu všechno, že jo, už pak je.
Na na Jirkovi a?
Myslím bodlákovi.
Na jirk strouhalovi a danielovi.
Aby existovala ta infrastruktura, že jo, jestli existuje já nevím, to jako asi není úplně dotaz na mě no.

Levíček Rostislav   48:36
Jo jo jo to to je jako Jirka bodlák. Samozřejmě jenom jsem nevěděl, jestli tam nezakládáme nějaký.
Jestli jsme tam něco nepotřebovali, mimo to, jestli to všechno dělal asi už pipelina, tak je to v pohodě.

Mluvčí 1   48:46
Ne.
Jo všecko už se pak zakládá pipelina, aspoň mě nic nenapadá. Takový ty sdílený komponenty jako je validátora spol. Tak ty jsou jako ve ve vysdíleným adresáři a taky není potřeba to řešit. Jo, to to pak je přes proměnný prostředí řešení.
Všechno.
Kde se co hledá?
Jo.

Levíček Rostislav   49:09
OK.

Strouhal Jiří   49:11
Dobře nebudu lhát, že teďka z toho mám takovou hlavu, ale až to začnu prostě nějak postupně odbavovat, tak.

Mluvčí 1   49:12
Link.
To je v pořádku.
No.

Levíček Rostislav   49:18
A jiřko to ber to ber to fakt jako že krůček za krůčkem není to nic jako fakt není potřeba se s tím stresovat a kdyžtak Honza pomůže.

Mluvčí 1   49:19
A naprosto v pořádku.

Strouhal Jiří   49:24
Jo.

Mluvčí 1   49:26
Ale.

Levíček Rostislav   49:31
Je to spíš o taková drbačka spousty malejch míst a výhoda je, že to jako budeš znát. No že když to prostě uděláš, to to jako.

Mluvčí 1   49:31
***** jsem se s tím jenom tejden, když jsem to dával dohromady.

Strouhal Jiří   49:39
No určitě, určitě. Tak mi jednak pomohlo II. Ty s těmi věci retence a ty DQ soubory aspoň se prostě ošahal. Viktory jo to.

Levíček Rostislav   49:52
No jasně.

Mluvčí 1   49:52
Hele ale ty jseš vnímavej vnímavej jako jo tobě se to řekne 1 a ty to nabereš jako.
Málokdo má fakt jako na rovinu. Málokdo je to takhle fungovat. Jo, takže jako za mě super.

Strouhal Jiří   49:59
Ne.
Děkuju, ale nevim no já si pak vždycky musím spustit. Já se pak vždycky musím spustit to video dvakrát třikrát a.

Levíček Rostislav   50:05
Souhlasím.

Mluvčí 1   50:07
No já vim.
Já já si myslím, že má v reprezentativní vzorek tady.

Strouhal Jiří   50:13
Dobře dobře děkuju, děkuju, děkuju, jsem rád jinak, teďka mi psal Tomáš frabar dneska jenom ty migrace z enterka do do outů, takže to musím teďka udělat a myslím, že po obědě v 1 ve 2 bych se na to podíval a postupně začnu prostě odbavovat a.

Levíček Rostislav   50:13
Já si taky myslím.

Strouhal Jiří   50:31
A pak budu řvát.

Levíček Rostislav   50:33
Jo, jo určitě určitě dobrý, dobrý.

Strouhal Jiří   50:34
Jo.
Dobře honzí, pošleš mi to nebo jak?

Levíček Rostislav   50:38
Dovolené chceš?

Mluvčí 1   50:40
Máš tady v tom chatu je link na ten text, kterej jsme teď tady zpozdili?

Strouhal Jiří   50:42
Jo jo já jsem nekoukal jo jo jo dobře děkuju, děkuju.

Mluvčí 1   50:45
Na.

Levíček Rostislav   50:45
Super.
Hele vypni nahrávání a chceš mi něco říct?

Mluvčí 1   50:49
Záznam.
A když ani záznam nepomůže, tak voláš.

Strouhal Jiří   50:52
Jo počkej vypnu zase nahrávání.

Strouhal Jiří zastavil(a) přepis
