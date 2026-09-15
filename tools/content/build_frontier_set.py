"""Reproducible authoring source for the 100-card Frontier set (no procedural artwork)."""
import json
import argparse
import hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
# id | Korean name | illustration subject | effect family
GROUPS={
'인간': '''ember_gate_sentinel|잿불 관문병|armored sentinel with rectangular sun shield and ember spear|front
banner_page|깃발 시종|young standard bearer carrying a torn blue lion banner|rally
siege_crossbowman|공성 석궁수|veteran kneeling behind an enormous steel crossbow|front
field_surgeon|야전 외과의|battle surgeon with linen bandages and lantern|heal
ash_lancer|재의 창기병|mounted lancer galloping through gray ash|rush
royal_cartographer|왕실 지도관|mapmaker unrolling a glowing tactical parchment|draw
iron_chaplain|강철 군목|armored chaplain raising a golden censer|ward
sunforge_smith|태양로 대장장이|blacksmith striking a radiant sword on an anvil|rally
breach_captain|돌파 대장|scarred captain kicking open a splintered fortress gate|squad
wounded_duelist|상처 입은 결투가|bandaged duelist with a chipped rapier|blood
cinder_marshal|불씨 원수|military marshal directing burning siege engines|fire
oathkeeper|서약 수호자|knight kneeling with an enormous engraved shield|death_heal
supply_rider|보급 기수|courier riding a shaggy horse with supply satchels|draw_heal
veteran_pikewall|노련한 창벽|veteran pikeman bracing a long pike in rain|ward_rally
dawn_paladin|새벽 성기사|paladin holding a dawnlit hammer over broken armor|heal_rally
volley_order|일제 사격 명령|crossbow bolts descending through a burning sky|blast
last_stand_oath|결사항전 서약|soldiers locking shields around a shattered banner|all_buff
supply_drop|전선 보급|supply crates lowered into a besieged courtyard|draw_spell
sunlit_triage|햇살 응급소|golden healing light falling onto an empty field hospital|heal_spell
scorched_advance|초토화 진군|a advancing wall of fire along a fortress causeway|sweep
sentinel_tower_shield|관문 대형 방패|massive dark steel tower shield leaning on rubble|guard_gear
sunforge_sabre|태양로 군도|curved military sword shedding orange sparks|flame_gear
commanders_spurs|지휘관의 박차|engraved golden riding spurs on a campaign map|rally_gear
medics_signet|의무관 인장|silver healing signet beside white bandages|heal_gear
martyrs_plate|순교자의 판금|cracked plate armor with a radiant heart-shaped relic|death_gear''',
'엘프': '''dew_scout|이슬 정찰병|elf scout crouched on a mossy branch with curved bow|draw
thorn_ambusher|가시 매복자|masked elf leaping through thorn vines with daggers|rush
moonwell_keeper|달샘 관리인|elf priestess lifting a bowl of moonlit water|heal
wind_script_sage|바람문자 현자|elder elf surrounded by floating leaf-shaped scripts|draw_ritual
rootshield_warden|뿌리방패 감시자|elf guardian holding a living root shield|ward
petal_blade_dancer|꽃잎 검무사|elf dancer with twin blades among crimson petals|rally
storm_perch_archer|폭풍 둥지 궁수|elf archer standing on a lightning struck treetop|front
seed_courier|씨앗 전령|elf courier carrying a luminous seed pod|ritual
mistpath_hunter|안개길 사냥꾼|hooded elf hunter emerging from silver woodland mist|draw_front
ancient_bark_guard|고목 껍질병|towering bark armored elf defending an ancient oak|death_heal
crystal_pool_seer|수정못 예언자|blindfolded elf touching reflected stars in a pool|draw_heal
wildfern_beastmaster|고사리 조련사|elf beastmaster leading a fern-covered stag|squad
aurora_stalker|극광 추적자|elf ranger with an icy bow beneath green aurora|cold
bloom_channeler|개화 영매|elf channeler with flowers growing from a staff|heal_rally
horizon_arrowmaster|지평선 명궁|elf master archer drawing a luminous longbow on a cliff|combo
briar_rain|찔레비|sharp luminous thorns raining into a forest clearing|sweep
moonlit_reading|달빛 독해|silver runes unfurling from a scroll under the moon|draw_spell
spring_revival|봄의 재생|green life returning to scorched roots|heal_spell
windward_oath|순풍의 맹세|a spiral of wind embracing a circle of bows|all_buff
frostseed_burst|서리씨앗 파열|ice crystal seeds bursting across dark bark|blast
moonstring_bow|달시위 활|silver crescent longbow with a moonlight string|draw_gear
thornweave_cloak|가시직조 망토|deep green cloak woven from thorny vines|guard_gear
sunseed_pendant|햇씨앗 목걸이|amber seed pendant glowing among fern leaves|heal_gear
stormfeather_quiver|폭풍깃 화살통|quiver filled with crackling storm-feather arrows|flame_gear
elderwood_spear|고목의 창|gnarled ancient wooden spear with a crystalline tip|rally_gear''',
'언데드': '''crypt_bellringer|납골 종지기|skeletal bellringer with a huge cracked bronze handbell|curse
shroud_apprentice|수의 견습생|young revenant wrapped in long funeral cloth|death_draw
marrow_collector|골수 수집가|bone collector carrying a cage of glowing ribs|death_damage
grave_lamplighter|무덤 점등사|undead lamplighter lighting blue grave lanterns|draw
bloodbound_knight|혈약 기사|vampiric knight with crimson fissures in black armor|blood
ossuary_guard|납골당 수위|huge skeletal guard with a door-sized bone shield|ward
corpse_ferryman|시체 뱃사공|hooded skeleton rowing a funeral skiff|death_heal
plague_apothecary|역병 약제사|undead physician uncorking green plague vials|poison
widows_revenant|미망인의 망령|spectral noblewoman holding a faded wedding veil|curse_heal
soul_tax_collector|영혼 징수관|undead tax collector weighing tiny ghost flames|draw_curse
coffin_breaker|관 파괴자|hulking ghoul tearing open an iron coffin|rush
bone_banner_lord|백골 깃발군주|skeletal commander bearing a banner of interwoven bones|squad
famine_acolyte|기근 수행자|gaunt undead monk with a hollow ceremonial bowl|blood_draw
night_vigil_wraith|밤샘 망령|armored blue ghost standing watch over graves|cold
red_moon_executor|적월 집행자|vampire executioner with a vast crimson crescent axe|low_front
funeral_tithe|장례 십일조|ghost flames drawn from a coffin into a ritual bowl|sacrifice_draw
marrow_detonation|골수 폭파|bone fragments and violet energy erupting from a skull|sacrifice_blast
crimson_pact|진홍 계약|a blood ink contract burning above a black altar|blood_spell
crypt_miasma|납골 독기|green violet miasma pouring from cracked crypt doors|sweep
restless_muster|잠들지 못한 소집|spectral hands lifting a banner from a cemetery|all_buff
ribcage_aegis|늑골 방벽|a shield woven from ribs and black iron|death_gear
widows_needle|미망인의 바늘|slender obsidian needle sword with red silk threads|heal_gear
soulglass_lantern|영혼유리 등불|a green soul trapped in a cracked glass lantern|draw_gear
bloodcourt_sword|혈정 군검|black ceremonial sword dripping luminous crimson mist|flame_gear
sepulchral_plate|묘실 판금|tarnished silver armor covered in funeral seals|guard_gear''',
'중립': '''frontier_militiaman|변경 자경병|weathered frontier guard with an improvised axe shield|rally
caravan_guard|대상단 호위|desert caravan guard with a curved blade|ward
runestone_scholar|룬석 학자|travelling scholar deciphering a floating runestone|draw
cinder_alchemist|잿불 연금술사|alchemist holding a volatile glowing orange flask|fire
frostbound_giant|빙결 거인|huge ice-armored giant lifting a stone club|cold
wandering_mender|떠돌이 수선사|old healer sewing golden light into a cloak|heal
quarry_breaker|채석장 파쇄꾼|muscular quarry worker wielding a stone maul|front
sandstep_mercenary|모래걸음 용병|masked mercenary dashing across sand with paired knives|rush
relic_diver|유물 잠수부|diver emerging from ancient flooded ruins with an orb|draw_heal
lantern_watchman|등불 파수꾼|lone watchman holding a bright brass lantern in fog|death_heal
emberwing_falconer|잿날개 매사냥꾼|falconer releasing an ember-winged hawk|draw_front
ironroot_colossus|철뿌리 거상|ancient iron colossus overgrown with roots|ward_rally
scarred_pitfighter|흉터 투기병|scarred arena fighter with chain-wrapped fists|blood
stormglass_magus|폭풍유리 마도사|mage bending lightning inside a glass sphere|combo
wayfarer_captain|길잡이 대장|trail captain rallying a diverse expedition|squad
flying_embers|날리는 잿불|a concentrated stream of fiery embers over black stone|blast
emergency_cache|비상 은닉처|open hidden chest of maps and supplies under roots|draw_spell
herbal_compress|약초 찜질|crushed luminous herbs wrapped in clean cloth|heal_spell
united_front|공동 전선|interlocking shields of several different cultures|all_buff
shrapnel_gust|파편 돌풍|a vortex of metal shards over a ruined arena|sweep
quarry_hammer|채석 망치|heavy chipped quarry hammer on stone rubble|rally_gear
frostglass_shield|서리유리 방패|translucent frozen glass shield with metal rim|guard_gear
travellers_compass|여행자의 나침반|intricate brass compass with a luminous needle|draw_gear
warmstone_charm|온돌석 부적|a red glowing stone wrapped in copper wire|heal_gear
last_light_cuirass|마지막 빛 흉갑|weathered breastplate with one glowing gem|death_gear'''}
# Concrete mechanics, rather than aliases to existing cards. Each op's text is generated from its data.
PROFILES={
'front':(2,2,2,[('front_damage',1)],[],['summon'],'metal'),
'rally':(2,1,3,[('front_buff',1,0)],[],['buff','summon'],'metal'),
'heal':(2,1,3,[('heal',2)],[],['low_hp','summon'],'holy'),
'rush':(3,2,2,[('ready',1)],[],['summon'],'arrow'),
'draw':(3,2,2,[('draw',1)],[],['draw','summon'],'arrow'),
'ward':(2,1,4,[],[],['buff'],'stone'),
'squad':(4,2,3,[('tokens',1)],[],['summon'],'metal'),
'blood':(2,3,3,[('self_damage',2)],[],['low_hp'],'blood'),
'fire':(4,2,3,[('front_damage',2)],[],['fire','summon'],'fire'),
'death_heal':(3,2,4,[],[('heal',2)],['death','low_hp'],'holy'),
'draw_heal':(4,2,3,[('draw',1),('heal',1)],[],['draw','low_hp'],'holy'),
'ward_rally':(4,1,6,[('front_buff',1,1)],[],['buff'],'stone'),
'heal_rally':(4,2,4,[('heal',2),('front_buff',0,1)],[],['buff','low_hp'],'holy'),
'draw_ritual':(4,1,4,[('draw',1),('ritual',1)],[],['draw','buff'],'wind'),
'ritual':(2,1,2,[('ritual',1)],[],['buff','summon'],'wind'),
'draw_front':(4,2,2,[('draw',1),('front_damage',1)],[],['draw','summon'],'arrow'),
'cold':(4,3,4,[('weaken',1)],[],['buff'],'ice'),
'combo':(4,2,4,[('combo_damage',1,3)],[],['draw','fire'],'lightning'),
'curse':(2,1,2,[('curse',1)],[],['death'],'shadow'),
'death_draw':(2,1,2,[],[('draw',1)],['death','draw'],'shadow'),
'death_damage':(3,2,3,[],[('hero_damage',2)],['death'],'bone'),
'poison':(4,1,4,[('all_damage',1),('curse',1)],[],['death','fire'],'poison'),
'curse_heal':(3,1,3,[('curse',1),('heal',1)],[],['death','low_hp'],'shadow'),
'draw_curse':(4,1,3,[('draw',1),('curse',1)],[],['death','draw'],'shadow'),
'blood_draw':(3,2,3,[('self_damage',2),('draw',1)],[],['low_hp','draw'],'blood'),
'low_front':(5,3,4,[('low_damage',1,3)],[],['low_hp','death'],'blood'),
'blast':(3,0,0,[('front_damage',4)],[],['fire'],'fire'),
'all_buff':(3,0,0,[('all_buff',1,1)],[],['buff','summon'],'holy'),
'draw_spell':(3,0,0,[('draw',2)],[],['draw'],'wind'),
'heal_spell':(2,0,0,[('heal',4),('front_buff',0,1)],[],['low_hp','buff'],'holy'),
'sweep':(4,0,0,[('all_damage',2)],[],['fire'],'fire'),
'sacrifice_draw':(1,0,0,[('sacrifice',1),('draw',2)],[],['death','draw'],'shadow'),
'sacrifice_blast':(3,0,0,[('sacrifice',1),('all_damage',3)],[],['death','fire'],'bone'),
'blood_spell':(2,0,0,[('self_damage',3),('draw',2),('heal',1)],[],['low_hp','draw'],'blood'),
'guard_gear':(2,0,0,[('target_buff',0,4)],[],['buff'],'stone'),
'flame_gear':(3,0,0,[('target_buff',1,0),('gear_hit',1)],[],['fire','buff'],'fire'),
'rally_gear':(2,0,0,[('target_buff',2,1)],[],['buff'],'metal'),
'heal_gear':(2,0,0,[('target_buff',1,1),('gear_heal',1)],[],['low_hp','buff'],'holy'),
'death_gear':(2,0,0,[('target_buff',0,2),('gear_death',2)],[],['death','buff'],'bone'),
'draw_gear':(3,0,0,[('target_buff',1,0),('gear_draw',1)],[],['draw','buff'],'wind'),
}
ATTR={'metal':'대지','holy':'빛','stone':'대지','fire':'화염','arrow':'바람','wind':'바람','ice':'물','lightning':'바람','shadow':'암흑','bone':'암흑','blood':'암흑','poison':'암흑'}
def op(t): return dict(op=t[0],amount=t[1],**({'extra':t[2]} if len(t)>2 else {}))
def text(e):
 a=e['amount'];b=e.get('extra',0)
 boosts=', '.join(([f'공격 +{a}'] if a else [])+([f'체력 +{b}'] if b else []))
 return {'front_damage':f'앞 적에게 피해 {a}','hero_damage':f'적 영웅에게 피해 {a}','all_damage':f'모든 적 유닛에게 피해 {a} (적 필드가 비면 영웅 피해 {a})','draw':f'카드 {a}장 드로우','heal':f'내 영웅 체력 {a} 회복','self_damage':f'내 영웅 체력 {a} 잃음','curse':f'적 저주 +{a}','ritual':f'의식 +{a}','ready':'즉시 공격 가능','tokens':f'즉시 공격 가능한 1/1 지원병 {a}장 소환 (빈 칸만)','front_buff':f'앞 아군 {boosts}','all_buff':f'모든 아군 {boosts}','target_buff':f'선택한 아군 {boosts}','weaken':f'앞 적 공격력 {a} 감소 (최소 0)','combo_damage':f'앞 적 피해 {a}, 이번 턴 카드 3장 이상 사용했다면 {b}','low_damage':f'앞 적 피해 {a}, 내 영웅 체력이 절반 이하라면 {b}','sacrifice':'선택한 아군 하나 희생','gear_hit':f'공격 후 적 영웅 피해 {a}','gear_heal':f'공격 후 내 영웅 회복 {a}','gear_draw':f'공격 후 카드 {a}장 드로우','gear_death':f'사망 시 적 영웅 피해 {a}'}[e['op']]
def build():
 cards=[];manifest=[]
 for race,rows in GROUPS.items():
  for i,line in enumerate(rows.splitlines()):
   id,name,subject,profile=line.split('|');cost,atk,hp,play,death,tags,impact=PROFILES[profile]
   kind='unit' if i<15 else 'spell' if i<20 else 'equipment'
   play=[op(x) for x in play];death=[op(x) for x in death]
   # Faction identities modify mechanics, not just names. All changes are reflected in text.
   if race=='엘프' and profile=='blast': play=[op(('combo_damage',2,5))];impact='ice';tags=['draw','fire']
   if race=='중립' and profile=='sweep': play=[op(('all_damage',1)),op(('weaken',2))];cost=3;impact='metal'
   if race=='엘프' and profile=='all_buff':play=[op(('all_buff',1,0)),op(('draw',1))];tags=['buff','draw'];impact='wind'
   if race=='언데드' and profile=='all_buff':play=[op(('self_damage',2)),op(('all_buff',2,0))];tags=['low_hp','summon'];impact='blood'
   if race=='중립' and profile=='all_buff':play=[op(('all_buff',0,2)),op(('heal',1))];tags=['buff','low_hp']
   if race=='중립' and profile=='draw_spell':play=[op(('draw',1)),op(('heal',2))];cost=2;tags=['draw','low_hp']
   if race=='엘프' and profile=='draw_spell':play=[op(('draw',2)),op(('ritual',1))];cost=4;tags=['draw','buff']
   if race=='엘프' and profile=='heal_spell':play=[op(('heal',3)),op(('ritual',1))];tags=['buff','low_hp']
   if race=='중립' and profile=='heal_spell':play=[op(('heal',6))];cost=3;tags=['low_hp']
   if race=='언데드' and profile=='flame_gear':play=[op(('target_buff',2,0)),op(('self_damage',2)),op(('gear_hit',1))];impact='blood';tags=['low_hp','fire']
   if race=='엘프' and profile=='flame_gear':play=[op(('target_buff',0,1)),op(('gear_hit',1))];cost=2;impact='lightning'
   if race=='중립' and kind=='equipment':
    # Expedition relics favour durability over the faction variants.
    play[0]['amount']=max(0,play[0]['amount']-1);play[0]['extra']=play[0].get('extra',0)+1
   if kind=='unit' and race=='중립': atk=max(1,atk-1);hp+=1
   if kind=='unit' and race=='엘프' and profile in ['rush','draw','ward','front']: atk+=1;hp=max(1,hp-1)
   # Weapon/material identity is independent of the mechanical effect family.
   impact={
    'siege_crossbowman':'arrow','ash_lancer':'metal','royal_cartographer':'metal',
    'iron_chaplain':'holy','supply_rider':'metal','volley_order':'arrow','martyrs_plate':'holy',
    'thorn_ambusher':'metal','storm_perch_archer':'lightning','ancient_bark_guard':'stone',
    'wildfern_beastmaster':'wind','briar_rain':'arrow','moonstring_bow':'arrow',
    'grave_lamplighter':'shadow','corpse_ferryman':'shadow','coffin_breaker':'bone',
    'bone_banner_lord':'bone','crypt_miasma':'poison','widows_needle':'shadow',
    'soulglass_lantern':'shadow','runestone_scholar':'shadow','quarry_breaker':'stone',
    'sandstep_mercenary':'metal','quarry_hammer':'stone','frostglass_shield':'ice',
    'last_light_cuirass':'holy',
   }.get(id,impact)
   desc=('소환 시 ' if kind=='unit' and play else '')+'; '.join(map(text,play))
   if death: desc+=(' / ' if desc else '')+'사망 시 '+'; '.join(map(text,death))
   if not desc: desc='전열을 오래 지키는 방어 유닛'
   c=dict(id=id,name=name,type=kind,race=race,attr=ATTR[impact],cost=cost,art=0,art_id=id,text=desc,starter=False,build_tags=tags,expansion='frontier_100',effects=play,death_effects=death,impact_profile=impact)
   if kind=='unit':c.update(attack=atk,health=hp)
   if any(e['op']=='sacrifice' for e in play):c['target']='ally'
   cards.append(c)
   manifest.append(dict(id=id,name=name,race=race,subject=subject,impact=impact,art_status='pending',prompt=f'Use case: stylized-concept. Original portrait collectible card illustration, dark fantasy painterly realism. Subject: {subject}. Distinctive silhouette, dramatic lighting, richly textured materials, central figure or object fills 75 percent of image, atmospheric environment, vertical 2:3 composition. No text, no card frame, no UI, no logos, no watermark, no existing franchise characters.'))
 manifest[0]['prompt']='Use case: stylized-concept. Asset type: original portrait collectible card illustration for Card Draft, no frame or typography. A human Ember Gate Sentinel in battered dark steel armor with a tall rectangular shield engraved with an abstract sun, a short spear glowing with ember sparks, guarding the burning gate of a mountain fortress at dusk. Full torso and distinctive shield occupy central 70%, readable silhouette, cinematic painterly dark fantasy game art, warm orange embers against deep blue shadows. Vertical 2:3 composition, no existing franchise characters, no logos, no writing, no watermark. Single standalone illustration.'
 assert len(cards)==100
 return cards,manifest
if __name__=='__main__':
 args=argparse.ArgumentParser(description=__doc__);args.add_argument('--publish',action='store_true');args=args.parse_args()
 cards,manifest=build()
 for record in manifest:
  art=ROOT/'assets/card_art/cards'/f"{record['id']}.png"
  if art.exists():record.update(art_status='generated',art_sha256=hashlib.sha256(art.read_bytes()).hexdigest(),generator='built-in image_gen')
 if args.publish:
  missing=[r['id'] for r in manifest if r['art_status']!='generated']
  if missing:raise SystemExit('Not published: missing art '+', '.join(missing))
  path=ROOT/'data/cards.json';existing=json.loads(path.read_text());existing=[c for c in existing if c.get('expansion')!='frontier_100'];assert not ({c['id'] for c in existing}&{c['id'] for c in cards})
  path.write_text(json.dumps(existing+cards,ensure_ascii=False,indent=4)+'\n')
  lorepath=ROOT/'data/card_lore.json';lore=json.loads(lorepath.read_text())
  origins={'인간':'무너진 관문을 되찾으려는 원정대','엘프':'불타버린 숲에 다시 뿌리를 내리는 수호자들','언데드':'전쟁의 끝에서도 잠들지 못한 망자들','중립':'어느 왕의 깃발에도 속하지 않는 변경의 생존자들'}
  stories=json.loads((ROOT/'docs/expansion/frontier-lore.json').read_text());assert len(stories)==100
  for c in cards:
   lore[c['id']]={'story':stories[c['id']],'role':c['text'],'hook':' / '.join(c['build_tags'])+' 연계를 연결하는 변경 원정 카드'}
  lorepath.write_text(json.dumps(lore,ensure_ascii=False,indent=2)+'\n')
 out=ROOT/'data/frontier_cards.json';out.write_text(json.dumps(cards,ensure_ascii=False,indent=2)+'\n')
 (ROOT/'docs/expansion/frontier-art-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
 lines=['# 변경 원정: 추가 카드 100장','','인간·엘프·언데드·공용 각 25장. 유닛 60장, 주문 20장, 장비 20장. 기존 시작 덱과 필살기는 유지한다.','','| 세력 | 카드 | 종류 | 비용 | 공/체 | 효과 | 타격 |','|---|---|---|---:|---|---|---|']
 for c in cards:
  values=[c['race'],c['name'],{'unit':'유닛','spell':'주문','equipment':'장비'}[c['type']],str(c['cost']),str(c.get('attack','—'))+'/'+str(c.get('health','—')),c['text'],c['impact_profile']]
  lines.append('| '+' | '.join(values)+' |')
 (ROOT/'docs/expansion/frontier-catalog.md').write_text('\n'.join(lines)+'\n')
 print(f'{len(cards)} authored cards in {out}')
