# Narration script (Swahili)

**Status: DRAFT — not yet usable with participants.** This is a first draft to speed up the
native-speaker translation (tasks T094). The app's current audio is a synthetic voice reading
this draft (`tools/synthesize_narration.py`, research R10 amendment); after any change below,
regenerate it. Before participants hear it:

1. A native Swahili speaker approved by Barefoot College revises every line (column "Swahili").
2. A second, independent speaker translates the revised lines back into English, without seeing
   the English source ([script.backtranslation.md](script.backtranslation.md)).
3. Differences are resolved, and partner staff sign off on the wording, including its fit with
   religious practice (constitution Principle VII).

Rules for the translation: simple everyday Swahili (Kiunguja is welcome), spoken to an adult
woman respectfully; say "most people", never "you are dirty"; never suggest that wudu is not
enough; the clip length limits stay (≤ 12 s, N04 and N19 ≤ 25 s).

Word choices to confirm with the reviewer:

- *kishikwambi* for "tablet" (BAKITA's word); "tableti" may be more familiar.
- *vijidudu* for "germs".
- *taa maalum* for "special lamp", *picha iliyotengenezwa na kishikwambi* for "a picture made by
  the tablet" (the simulation message, Principle I).
- *miondoko sita* for "the six movements".

`tools/import_narration.sh` and the app read clip IDs only; the text below is for the voice
artist and the reviewers, and is copied into `narration-manifest.json` once approved.

| Clip | State | English source | Swahili (draft) | Reviewed |
|---|---|---|---|---|
| N01 | positioning | Please place your hands under the screen, with your palms facing up. | Tafadhali weka mikono yako chini ya skrini, viganja vikiangalia juu. | ☐ |
| N02 | positioning (no hands for >2 s) | Bring your hands a little closer, into the light. | Sogeza mikono yako karibu kidogo, kwenye mwanga. | ☐ |
| N03 | normalView | These are your hands. They look clean, don't they? | Hii ni mikono yako. Inaonekana safi, sivyo? | ☐ |
| N04 | uvIntro | Now we will switch on a special lamp. This is a picture made by the tablet, not a real test. It shows what a real lamp can reveal on most people's hands: things our eyes cannot see. | Sasa tutawasha taa maalum. Hii ni picha iliyotengenezwa na kishikwambi, si kipimo halisi. Inaonyesha kile ambacho taa halisi inaweza kufichua kwenye mikono ya watu wengi: vitu ambavyo macho yetu hayawezi kuona. | ☐ |
| N05 | uvReveal | Look: under this lamp, the hidden things shine. They gather at the fingertips, thumbs, between the fingers and on the back of the hand. | Angalia: chini ya taa hii, vitu vilivyojificha vinang'aa. Vinakusanyika kwenye ncha za vidole, vidole gumba, katikati ya vidole na nyuma ya mkono. | ☐ |
| N06 | uvReveal (prompt) | Turn your hands over and look at the other side. | Geuza mikono yako, uangalie upande wa pili. | ☐ |
| N07 | uvReveal (prompt) | Touch the light button to switch the special lamp off, and touch it again to switch it on. Clear is not always clean. | Gusa kitufe cha taa kuzima taa maalum, na ukiguse tena kuiwasha. Kuonekana safi haimaanishi ni safi kweli. | ☐ |
| N08 | quickRinseDemo | When most people wash quickly, only the middle of the hand gets clean. The rest stays. | Watu wengi wanaponawa haraka, katikati ya kiganja tu ndiko kunakosafika. Sehemu nyingine zinabaki. | ☐ |
| N09 | rehearsal intro | Let's practice the six movements that clean the whole hand. Rub your hands together, without water, as you see. | Tufanye mazoezi ya miondoko sita inayosafisha mkono mzima. Sugua mikono yako pamoja, bila maji, kama unavyoona. | ☐ |
| N10 | rehearsal step 1 | Palm to palm. | Kiganja kwa kiganja. | ☐ |
| N11 | rehearsal step 2 | One palm over the back of the other hand, then change. | Kiganja kimoja juu ya mgongo wa mkono mwingine, kisha badilisha. | ☐ |
| N12 | rehearsal step 3 | Palm to palm with fingers crossed. | Kiganja kwa kiganja, vidole vikiwa vimeingiliana. | ☐ |
| N13 | rehearsal step 4 | The backs of the fingers in the other palm. | Migongo ya vidole ndani ya kiganja cha mkono mwingine. | ☐ |
| N14 | rehearsal step 5 | Hold each thumb and turn it. | Shika kila kidole gumba na ukizungushe. | ☐ |
| N15 | rehearsal step 6 | Rub the fingertips in the other palm. | Sugua ncha za vidole ndani ya kiganja cha mkono mwingine. | ☐ |
| N16 | rehearsal paused | Keep both hands under the screen. | Weka mikono yote miwili chini ya skrini. | ☐ |
| N17 | rehearsal done | Well done. With these six movements, the whole hand gets clean. | Hongera. Kwa miondoko hii sita, mkono mzima unasafika. | ☐ |
| N18 | realWashPrompt | Now let's wash with soap and water, the same way. Soap and water at the important moments help protect you and your family, together with the washing you already do every day. | Sasa tunawe kwa sabuni na maji, kwa njia ileile. Sabuni na maji katika nyakati muhimu husaidia kukulinda wewe na familia yako, pamoja na kunawa unakofanya kila siku. | ☐ |
| N19 | debrief | Remember: the glowing marks today were a picture made by the tablet. A real special lamp shows the same thing. Germs hide where we do not see them, and washing with soap, using the six movements, removes them. Thank you. | Kumbuka: alama zilizong'aa leo zilikuwa picha iliyotengenezwa na kishikwambi. Taa halisi maalum inaonyesha kitu hicho hicho. Vijidudu hujificha mahali tusipoviona, na kunawa kwa sabuni, kwa kutumia miondoko sita, huviondoa. Asante. | ☐ |
| N20 | aborted | Thank you. We can stop here. | Asante. Tunaweza kuishia hapa. | ☐ |
| N21 | face guard | Only the hands, please. Let's move the tablet a little. | Mikono tu, tafadhali. Tusogeze kishikwambi kidogo. | ☐ |
