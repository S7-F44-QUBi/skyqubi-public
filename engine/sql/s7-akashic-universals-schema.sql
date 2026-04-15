-- engine/sql/s7-akashic-universals-schema.sql
-- S7 Akashic Universals — unification of common language and symbols
-- through all history.
--
-- Each row is a universal concept that appears across major
-- historical languages and symbol systems. The concept is indexed
-- by its English canonical name, but is matched against any of its
-- multi-language surface_forms at encode time. All forms collapse
-- to the same (curve_value, plane_affinity) — so a text that
-- mentions 'mayim' (Hebrew water), 'agua' (Spanish water), or
-- 'water' all land on the same Akashic position.
--
-- The goal is NOT a full multilingual dictionary. The goal is the
-- small set of concepts present in every major civilization —
-- cosmos, creation, covenant, person, virtue, time. Finite, high-
-- signal, civilian-only.
--
-- Lives in DB:    s7_cws
-- Schema:         akashic
-- Prerequisites:  extension "uuid-ossp" (already loaded in s7_cws)

CREATE TABLE IF NOT EXISTS akashic.universals (
    id               UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
    concept          TEXT          NOT NULL UNIQUE,      -- canonical English key
    curve_value      SMALLINT      NOT NULL CHECK (curve_value BETWEEN -7 AND 7),
    plane_affinity   SMALLINT[]    NOT NULL,             -- 7-plane indices 0..6
    surface_forms    TEXT[]        NOT NULL,             -- lowercased tokens across languages
    origin_note      TEXT,                               -- which traditions / languages
    created_at       TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE akashic.universals IS
  'Unified universals — concepts appearing across all major historical languages and symbol systems. Feeds the Phase 5 Akashic Language Index.';

-- Index the surface_forms for fast lookup during encode.
CREATE INDEX IF NOT EXISTS universals_surface_gin
  ON akashic.universals USING gin (surface_forms);

-- ── Seed: ~100 universals ────────────────────────────────────────
-- Columns: concept, curve_value (-7..+7), plane_affinity, surface_forms
-- Planes (Phase 5):
--   0 Sensory | 1 Episodic | 2 Semantic | 3 Associative
--   4 Procedural | 5 Relational | 6 Lexical
-- Curve value: negative = structure/foundation pole, positive = nurture/growth pole
--
-- Surface forms below use a minimal transliteration — Latin letters only —
-- so the existing _TOKEN_RE in s7_akashic.py (which matches [a-zA-Z]+)
-- picks them up without Unicode normalization work. Native scripts can
-- be added in phase 2.

INSERT INTO akashic.universals (concept, curve_value, plane_affinity, surface_forms, origin_note) VALUES

-- ── COSMOS (the sky, the great lights, the elements) ─────────────
('sun',        3, '{0,1}',   '{sun,sol,helios,shemesh,shams,surya,taiyo,ri,ra}',       'en/la/gr/he/ar/skt/jp/zh/egy'),
('moon',       1, '{0,1}',   '{moon,luna,selene,yareah,qamar,chandra,tsuki,yue,iah}',  'en/la/gr/he/ar/skt/jp/zh/egy'),
('star',       2, '{0,1}',   '{star,stella,aster,kokhav,najm,tara,hoshi,xing}',        'en/la/gr/he/ar/skt/jp/zh'),
('sky',        0, '{0,5}',   '{sky,caelum,ouranos,shamayim,sama,akasha,sora,tian}',    'en/la/gr/he/ar/skt/jp/zh'),
('earth',     -3, '{0,5}',   '{earth,terra,ge,eretz,ard,prithvi,tsuchi,di}',           'en/la/gr/he/ar/skt/jp/zh'),
('fire',       4, '{0,4}',   '{fire,ignis,pyr,esh,nar,agni,hi,huo}',                   'en/la/gr/he/ar/skt/jp/zh'),
('water',     -2, '{0,4}',   '{water,aqua,hydor,mayim,ma,apas,mizu,shui,aqua}',        'en/la/gr/he/ar/skt/jp/zh'),
('wind',       0, '{0,4}',   '{wind,ventus,anemos,ruach,rih,vayu,kaze,feng}',          'en/la/gr/he/ar/skt/jp/zh'),
('light',      6, '{0,2}',   '{light,lux,phos,or,nur,jyoti,hikari,guang}',             'en/la/gr/he/ar/skt/jp/zh'),
('dark',      -4, '{0,2}',   '{dark,tenebrae,skotos,choshekh,zalam,tamas,kurai,an}',   'en/la/gr/he/ar/skt/jp/zh'),
('mountain',  -5, '{0,5}',   '{mountain,mons,oros,har,jabal,parvata,yama,shan}',       'en/la/gr/he/ar/skt/jp/zh'),
('river',      1, '{0,4}',   '{river,flumen,potamos,nahar,nahr,nadi,kawa,he}',         'en/la/gr/he/ar/skt/jp/zh'),
('sea',       -1, '{0,4}',   '{sea,mare,thalassa,yam,bahr,samudra,umi,hai}',           'en/la/gr/he/ar/skt/jp/zh'),
('tree',       2, '{0,5}',   '{tree,arbor,dendron,etz,shajar,vriksha,ki,shu}',         'en/la/gr/he/ar/skt/jp/zh'),
('stone',     -6, '{0,5}',   '{stone,lapis,lithos,even,hajar,pashana,ishi,shi}',       'en/la/gr/he/ar/skt/jp/zh'),

-- ── CREATION / FOUNDATION ────────────────────────────────────────
('word',       5, '{2,6}',   '{word,verbum,logos,davar,kalam,vacana,kotoba,ci}',       'en/la/gr/he/ar/skt/jp/zh'),
('name',       4, '{2,6}',   '{name,nomen,onoma,shem,ism,nama,na,ming}',               'en/la/gr/he/ar/skt/jp/zh'),
('beginning', -6, '{1,5}',   '{beginning,principium,arche,bereshit,bad,adi,hajime,shi}', 'en/la/gr/he/ar/skt/jp/zh'),
('first',     -5, '{1,5}',   '{first,primus,protos,rishon,awwal,prathama,hitotsu,yi}', 'en/la/gr/he/ar/skt/jp/zh'),
('door',       0, '{5}',     '{door,ostium,thura,delet,bab,dvara,to,men}',             'en/la/gr/he/ar/skt/jp/zh'),
('way',        3, '{4,5}',   '{way,via,hodos,derech,tariq,marga,michi,dao}',           'en/la/gr/he/ar/skt/jp/zh'),
('path',       2, '{4,5}',   '{path,semita,atrapos,netiv,sabil,pantha,michi,lu}',      'en/la/gr/he/ar/skt/jp/zh'),
('house',     -2, '{5}',     '{house,domus,oikos,bayit,bayt,griha,ie,jia}',            'en/la/gr/he/ar/skt/jp/zh'),
('temple',    -4, '{5}',     '{temple,templum,hieron,hekhal,haykal,mandir,tera,si}',   'en/la/gr/he/ar/skt/jp/zh'),
('foundation', -7, '{5}',    '{foundation,fundamentum,themelion,yesod,asas,mula,dodai,jichu}', 'en/la/gr/he/ar/skt/jp/zh'),
('pillar',    -5, '{5}',     '{pillar,columna,stulos,amud,amud,stambha,hashira,zhu}',  'en/la/gr/he/ar/skt/jp/zh'),

-- ── COVENANT / WITNESS ───────────────────────────────────────────
('covenant',  -5, '{2,3}',   '{covenant,foedus,diatheke,berit,ahd,samaya,keiyaku,meng}', 'en/la/gr/he/ar/skt/jp/zh'),
('oath',      -4, '{2,3}',   '{oath,juramentum,horkos,shvuah,qasam,shapatha,chikai,shi}', 'en/la/gr/he/ar/skt/jp/zh'),
('witness',    3, '{2,6}',   '{witness,testis,martus,ed,shahid,sakshin,shonin,zheng}', 'en/la/gr/he/ar/skt/jp/zh'),
('truth',      7, '{2}',     '{truth,veritas,aletheia,emet,haqq,satya,shin,zhen}',     'en/la/gr/he/ar/skt/jp/zh'),
('book',      -2, '{6}',     '{book,liber,biblos,sefer,kitab,pustaka,hon,shu}',        'en/la/gr/he/ar/skt/jp/zh'),
('scroll',    -3, '{6}',     '{scroll,volumen,kephale,megillah,makhtut,patra,makimono,juan}', 'en/la/gr/he/ar/skt/jp/zh'),
('seal',      -3, '{5,6}',   '{seal,sigillum,sphragis,chotam,khatm,mudra,in,yin}',     'en/la/gr/he/ar/skt/jp/zh'),
('law',       -4, '{2,6}',   '{law,lex,nomos,torah,shariah,dharma,ho,fa}',             'en/la/gr/he/ar/skt/jp/zh'),
('promise',    3, '{2,3}',   '{promise,promissum,epangelia,havtachah,waad,pratijna,yakusoku,yue}', 'en/la/gr/he/ar/skt/jp/zh'),
('sign',       1, '{0,2}',   '{sign,signum,semeion,ot,aya,lakshana,shirushi,zhao}',    'en/la/gr/he/ar/skt/jp/zh'),

-- ── VIRTUE / APTITUDE ────────────────────────────────────────────
('love',       6, '{3}',     '{love,amor,agape,ahavah,hubb,prema,ai,ai}',              'en/la/gr/he/ar/skt/jp/zh'),
('mercy',      6, '{3}',     '{mercy,misericordia,eleos,chesed,rahma,karuna,jihi,ci}', 'en/la/gr/he/ar/skt/jp/zh'),
('justice',    4, '{2,3}',   '{justice,iustitia,dike,tzedek,adl,nyaya,seigi,yi}',      'en/la/gr/he/ar/skt/jp/zh'),
('peace',      5, '{3}',     '{peace,pax,eirene,shalom,salam,shanti,heiwa,he}',        'en/la/gr/he/ar/skt/jp/zh'),
('wisdom',     5, '{2}',     '{wisdom,sapientia,sophia,chokmah,hikma,prajna,chie,zhi}', 'en/la/gr/he/ar/skt/jp/zh'),
('knowledge',  3, '{2}',     '{knowledge,scientia,gnosis,daat,ilm,jnana,chishiki,zhi}', 'en/la/gr/he/ar/skt/jp/zh'),
('understanding', 3, '{2,3}','{understanding,intellectus,synesis,binah,fahm,buddhi,rikai,li}', 'en/la/gr/he/ar/skt/jp/zh'),
('faith',      5, '{3}',     '{faith,fides,pistis,emunah,iman,shraddha,shinko,xin}',   'en/la/gr/he/ar/skt/jp/zh'),
('hope',       6, '{3}',     '{hope,spes,elpis,tikvah,amal,asha,kibo,wang}',           'en/la/gr/he/ar/skt/jp/zh'),
('joy',        5, '{3}',     '{joy,gaudium,chara,simcha,farah,ananda,yorokobi,xi}',    'en/la/gr/he/ar/skt/jp/zh'),
('good',       4, '{2}',     '{good,bonum,agathos,tov,khayr,subha,yoi,shan}',          'en/la/gr/he/ar/skt/jp/zh'),
('evil',      -6, '{2}',     '{evil,malum,kakos,ra,sharr,papa,warui,e}',               'en/la/gr/he/ar/skt/jp/zh'),
('life',       5, '{3,4}',   '{life,vita,zoe,chayim,hayat,jivana,inochi,sheng}',       'en/la/gr/he/ar/skt/jp/zh'),
('death',     -5, '{3,4}',   '{death,mors,thanatos,mavet,mawt,mrtyu,shi,si}',          'en/la/gr/he/ar/skt/jp/zh'),

-- ── PERSON / SPIRIT ──────────────────────────────────────────────
('man',        0, '{3}',     '{man,homo,anthropos,ish,rajul,manushya,otoko,nan}',      'en/la/gr/he/ar/skt/jp/zh'),
('woman',      0, '{3}',     '{woman,femina,gyne,ishah,imraa,stri,onna,nu}',           'en/la/gr/he/ar/skt/jp/zh'),
('child',      4, '{3}',     '{child,infans,teknon,yeled,tifl,bala,ko,zi}',            'en/la/gr/he/ar/skt/jp/zh'),
('father',    -5, '{3}',     '{father,pater,pater,av,abu,pitr,chichi,fu}',             'en/la/gr/he/ar/skt/jp/zh'),
('mother',     5, '{3}',     '{mother,mater,meter,em,umm,matr,haha,mu}',               'en/la/gr/he/ar/skt/jp/zh'),
('brother',    1, '{3}',     '{brother,frater,adelphos,ach,akh,bhratr,ani,xiong}',     'en/la/gr/he/ar/skt/jp/zh'),
('sister',     1, '{3}',     '{sister,soror,adelphe,achot,ukht,svasr,ane,jie}',        'en/la/gr/he/ar/skt/jp/zh'),
('king',      -3, '{3,5}',   '{king,rex,basileus,melech,malik,raja,o,wang}',           'en/la/gr/he/ar/skt/jp/zh'),
('friend',     4, '{3}',     '{friend,amicus,philos,chaver,sadiq,mitra,tomo,you}',     'en/la/gr/he/ar/skt/jp/zh'),
('soul',       6, '{2,3}',   '{soul,anima,psyche,nefesh,nafs,atman,tamashii,hun}',     'en/la/gr/he/ar/skt/jp/zh'),
('spirit',     6, '{2,3}',   '{spirit,spiritus,pneuma,ruach,ruh,prana,rei,shen}',      'en/la/gr/he/ar/skt/jp/zh'),
('heart',      5, '{3}',     '{heart,cor,kardia,lev,qalb,hrdaya,kokoro,xin}',          'en/la/gr/he/ar/skt/jp/zh'),
('mind',       3, '{2}',     '{mind,mens,nous,sekhel,aql,manas,kokoro,xin}',           'en/la/gr/he/ar/skt/jp/zh'),
('breath',     4, '{0,3}',   '{breath,anima,pneuma,neshamah,nafas,prana,iki,qi}',      'en/la/gr/he/ar/skt/jp/zh'),
('voice',      2, '{0,6}',   '{voice,vox,phone,qol,sawt,vac,koe,sheng}',               'en/la/gr/he/ar/skt/jp/zh'),

-- ── TIME / ORDER ─────────────────────────────────────────────────
('day',        3, '{1}',     '{day,dies,hemera,yom,yawm,divasa,hi,ri}',                'en/la/gr/he/ar/skt/jp/zh'),
('night',     -3, '{1}',     '{night,nox,nux,layla,layl,ratri,yoru,ye}',               'en/la/gr/he/ar/skt/jp/zh'),
('year',       1, '{1}',     '{year,annus,etos,shanah,sanah,varsha,toshi,nian}',       'en/la/gr/he/ar/skt/jp/zh'),
('age',       -2, '{1}',     '{age,aetas,aion,olam,dahr,yuga,yo,shi}',                 'en/la/gr/he/ar/skt/jp/zh'),
('dawn',       4, '{1}',     '{dawn,aurora,eos,shachar,fajr,ushas,akatsuki,li}',       'en/la/gr/he/ar/skt/jp/zh'),
('end',       -3, '{1,5}',   '{end,finis,telos,ketz,akhir,anta,owari,zhong}',          'en/la/gr/he/ar/skt/jp/zh'),
('new',        4, '{1}',     '{new,novus,neos,chadash,jadid,nava,atarashii,xin}',      'en/la/gr/he/ar/skt/jp/zh'),
('old',       -4, '{1}',     '{old,vetus,palaios,zaken,qadim,pura,furui,lao}',         'en/la/gr/he/ar/skt/jp/zh'),

-- ── NUMBER / UNITY ──────────────────────────────────────────────
('one',       -2, '{5}',     '{one,unus,hen,echad,wahid,eka,ichi,yi}',                 'en/la/gr/he/ar/skt/jp/zh'),
('two',        0, '{5}',     '{two,duo,duo,shnayim,ithnayn,dvi,ni,er}',                'en/la/gr/he/ar/skt/jp/zh'),
('three',      2, '{5}',     '{three,tres,tria,shalosh,thalatha,tri,san,san}',         'en/la/gr/he/ar/skt/jp/zh'),
('seven',      3, '{5}',     '{seven,septem,hepta,shivah,saba,sapta,nana,qi}',         'en/la/gr/he/ar/skt/jp/zh'),
('many',       1, '{5}',     '{many,multi,polloi,rabim,kathir,bahu,oku,duo}',          'en/la/gr/he/ar/skt/jp/zh'),
('all',        2, '{5}',     '{all,omnis,pas,kol,kull,sarva,subete,jie}',              'en/la/gr/he/ar/skt/jp/zh'),
('none',      -2, '{5}',     '{none,nullus,oudeis,ayin,lashay,nahi,nashi,wu}',         'en/la/gr/he/ar/skt/jp/zh'),
('whole',      3, '{5}',     '{whole,integer,holos,shalem,kamil,purna,mattaki,quan}',  'en/la/gr/he/ar/skt/jp/zh'),

-- ── ACTION / JOURNEY ────────────────────────────────────────────
('go',         1, '{4}',     '{go,ire,erchomai,halakh,dhahaba,gam,iku,xing}',          'en/la/gr/he/ar/skt/jp/zh'),
('come',      -1, '{4}',     '{come,venire,erchomai,ba,qadima,aya,kuru,lai}',          'en/la/gr/he/ar/skt/jp/zh'),
('return',    -1, '{4}',     '{return,redire,anastrepho,shuv,awda,nivrt,kaeru,gui}',   'en/la/gr/he/ar/skt/jp/zh'),
('rest',       3, '{3,4}',   '{rest,quies,anapausis,menuchah,raha,visrama,yasumi,xi}', 'en/la/gr/he/ar/skt/jp/zh'),
('build',      2, '{4,5}',   '{build,aedificare,oikodomeo,banah,bana,nirmana,tateru,jian}', 'en/la/gr/he/ar/skt/jp/zh'),
('give',       3, '{3,4}',   '{give,dare,didomi,natan,ata,da,ataeru,gei}',             'en/la/gr/he/ar/skt/jp/zh'),
('take',      -1, '{3,4}',   '{take,capere,lambano,laqach,akhadha,graha,toru,qu}',     'en/la/gr/he/ar/skt/jp/zh'),
('seek',       3, '{4}',     '{seek,quaerere,zeteo,biqesh,baha,gaveshana,motomeru,qiu}', 'en/la/gr/he/ar/skt/jp/zh'),
('find',       4, '{4}',     '{find,invenire,heurisko,matza,wajada,prapta,mitsukeru,zhao}', 'en/la/gr/he/ar/skt/jp/zh'),
('see',        2, '{0,2}',   '{see,videre,horao,raah,raa,pashya,miru,jian}',           'en/la/gr/he/ar/skt/jp/zh'),
('hear',       2, '{0,2}',   '{hear,audire,akouo,shama,sami,shruti,kiku,wen}',         'en/la/gr/he/ar/skt/jp/zh'),
('speak',      3, '{6}',     '{speak,loqui,lego,davar,qala,vadati,hanasu,shuo}',       'en/la/gr/he/ar/skt/jp/zh'),
('write',      2, '{6}',     '{write,scribere,grapho,katav,kataba,likh,kaku,xie}',     'en/la/gr/he/ar/skt/jp/zh'),
('read',       3, '{6}',     '{read,legere,anaginosko,qara,qaraa,patha,yomu,du}',      'en/la/gr/he/ar/skt/jp/zh'),
('remember',   1, '{1}',     '{remember,meminisse,mnemoneuo,zakhar,dhakara,smr,oboeru,ji}', 'en/la/gr/he/ar/skt/jp/zh'),
('keep',       0, '{4,5}',   '{keep,servare,tereo,shamar,hafaza,raksha,mamoru,shou}',  'en/la/gr/he/ar/skt/jp/zh'),
('pray',       4, '{3}',     '{pray,orare,proseuchomai,palal,daa,prarthana,inoru,qi}', 'en/la/gr/he/ar/skt/jp/zh'),
('bless',      5, '{3}',     '{bless,benedicere,eulogeo,barach,baraka,ashirvada,shukufuku,zhu}', 'en/la/gr/he/ar/skt/jp/zh'),

-- ── HEAVENLY / COVENANT NAMES (civilian, cross-tradition) ────────
('holy',       6, '{2,3}',   '{holy,sanctus,hagios,qadosh,qadus,pavitra,sei,sheng}',   'en/la/gr/he/ar/skt/jp/zh'),
('glory',      5, '{2,3}',   '{glory,gloria,doxa,kavod,majd,mahima,eiko,rong}',        'en/la/gr/he/ar/skt/jp/zh'),
('god',        5, '{3}',     '{god,deus,theos,elohim,allah,deva,kami,shen}',           'en/la/gr/he/ar/skt/jp/zh'),
('lord',       3, '{3,5}',   '{lord,dominus,kurios,adonai,rabb,prabhu,shu,zhu}',       'en/la/gr/he/ar/skt/jp/zh'),

-- ── STRUCTURE / NEGATION (for discernment) ───────────────────────
('no',        -1, '{2}',     '{no,non,ou,lo,la,na,iie,bu}',                            'en/la/gr/he/ar/skt/jp/zh'),
('yes',        1, '{2}',     '{yes,ita,nai,ken,naam,ha,hai,shi}',                      'en/la/gr/he/ar/skt/jp/zh')

ON CONFLICT (concept) DO NOTHING;
