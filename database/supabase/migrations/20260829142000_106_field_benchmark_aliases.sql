-- Scope-preserving aliases from the field benchmark.  Every alias keeps the
-- modality, anatomy, protocol and/or specimen that distinguishes its item.
-- Broad terms remain out of the alias table and are handled as abstentions.

begin;

insert into catalog.item_aliases(
  item_id, alias, normalized_alias, alias_type, confidence, status,
  source_note, approved_at
)
values
  ('acae8edf-0d1b-5883-8e47-697834d9b3f1','Densitometría dual del antebrazo','densitometria dual del antebrazo','synonym',1,'approved','Resolver benchmark v2: preserves dual forearm scope.',now()),
  ('b829b973-64ca-5424-b05a-83d93cdea5dd','Densitometría dual de cadera','densitometria dual de cadera','synonym',1,'approved','Resolver benchmark v2: preserves dual hip scope.',now()),
  ('580717cd-4d8f-52bd-ba36-42112546cdca','Densitometría de columna lumbar','densitometria de columna lumbar','synonym',1,'approved','Resolver benchmark v2: preserves lumbar scope.',now()),
  ('b6e39b46-ebf0-5095-9e82-dacd11250c54','Densitometría ósea de cadera y antebrazo','densitometria osea de cadera y antebrazo','synonym',1,'approved','Resolver benchmark v2: preserves two-site scope.',now()),
  ('5bd35412-4e3c-5a2a-a809-ab0b10fe3ce6','Densitometría ósea de columna y cadera','densitometria osea de columna y cadera','synonym',1,'approved','Resolver benchmark v2: preserves two-site scope.',now()),
  ('d9aa15c4-0d92-5e01-8607-d9d6d60dae7b','Densitometría ósea de cuerpo completo','densitometria osea de cuerpo completo','synonym',1,'approved','Resolver benchmark v2: preserves whole-body scope.',now()),
  ('5627c136-27fe-57c1-85d0-22ccfd6d5d7f','Espirometría para chequeo','espirometria para chequeo','synonym',1,'approved','Resolver benchmark v2: preserves check-up protocol.',now()),
  ('dfa3afca-fb22-5c20-8e3c-34168fe1961f','Espirometría con prueba broncodilatadora','espirometria con prueba broncodilatadora','synonym',1,'approved','Resolver benchmark v2: preserves bronchodilator protocol.',now()),
  ('971b189f-eafb-5ac9-bb90-9374dbed5f6e','Prueba de espirometría simple','prueba de espirometria simple','synonym',1,'approved','Resolver benchmark v2: preserves simple protocol.',now()),
  ('c2c10805-c1e4-5f65-a9a5-b62f20675945','Eco cardiaco transtorácico','eco cardiaco transtoracico','synonym',1,'approved','Resolver benchmark v2: preserves transthoracic scope.',now()),
  ('fba52c7e-ecff-5c72-b827-783f33ae69f7','Monitoreo Holter cardíaco','monitoreo holter cardiaco','synonym',1,'approved','Resolver benchmark v2: preserves cardiac Holter scope.',now()),
  ('2d17283e-3fe2-5e9e-8df8-7c305121af54','Monitoreo ambulatorio de presión arterial (MAPA)','monitoreo ambulatorio de presion arterial mapa','synonym',1,'approved','Resolver benchmark v2: preserves ambulatory blood-pressure scope.',now()),
  ('71c7e789-31c8-5da0-8dd5-ef0a7088222c','Gasometría de sangre venosa','gasometria de sangre venosa','synonym',1,'approved','Resolver benchmark v2: preserves venous specimen.',now()),
  ('ff01230e-0c64-5774-a4c2-1740e9a0580b','Electrocardiograma para niños','electrocardiograma para ninos','synonym',1,'approved','Resolver benchmark v2: preserves pediatric scope.',now()),
  ('dd018aa7-8f27-5485-8332-e590ed544249','PCR para SARS-CoV-2','pcr para sars cov 2','abbreviation',1,'approved','Resolver benchmark v2: preserves PCR method and target.',now()),
  ('69e729be-be23-5e55-8e25-b971e16ea5d2','Antígeno nasal de SARS-CoV-2','antigeno nasal de sars cov 2','synonym',1,'approved','Resolver benchmark v2: preserves nasal specimen and antigen method.',now()),
  ('d2969c40-c066-570c-8907-d8e32541c2e6','Prueba de antígeno para COVID-19','prueba de antigeno para covid 19','synonym',1,'approved','Resolver benchmark v2: preserves antigen method.',now()),
  ('9128e055-04f4-5e4c-9ff4-c274d1f3bc84','Anticuerpos IgG contra SARS-CoV-2','anticuerpos igg contra sars cov 2','synonym',1,'approved','Resolver benchmark v2: preserves IgG target.',now()),
  ('d66b304c-afeb-53c9-9cae-1cdd529db5ad','Perfil de anticuerpos COVID IgG IgM','perfil de anticuerpos covid igg igm','synonym',1,'approved','Resolver benchmark v2: preserves antibody panel scope.',now()),
  ('1afa8fa6-94c8-5f16-a78d-6ced19216a08','Ultrasonido 4D','ultrasonido 4d','synonym',1,'approved','Resolver benchmark v2: preserves four-dimensional protocol.',now()),
  ('7f317fce-9c66-5542-aea0-92e5759f19dc','Ultrasonido 4D para gemelos','ultrasonido 4d para gemelos','synonym',1,'approved','Resolver benchmark v2: preserves twin-pregnancy scope.',now()),
  ('b3ec7d1e-9e20-55ec-9bfc-d72c0836c7dd','Ultrasonido de abdomen superior','ultrasonido de abdomen superior','synonym',1,'approved','Resolver benchmark v2: preserves upper-abdomen scope.',now()),
  ('856b3bf3-9c10-5a98-81b7-e2ad118c5d3b','Ultrasonido de cuello','ultrasonido de cuello','synonym',1,'approved','Resolver benchmark v2: preserves neck scope.',now()),
  ('2b90785a-8f47-5eb1-9daf-341b9868b42c','Ultrasonido abdominal con prueba de Boyden','ultrasonido abdominal con prueba de boyden','synonym',1,'approved','Resolver benchmark v2: preserves Boyden maneuver.',now()),
  ('6381074e-a19b-5c59-9027-c6fc6bd9150b','Ecografía renal','ecografia renal','synonym',1,'approved','Resolver benchmark v2: preserves renal anatomy.',now()),
  ('a40351fd-f38e-5bdd-b827-c794874389b5','Ecografía testicular','ecografia testicular','synonym',1,'approved','Resolver benchmark v2: preserves testicular anatomy.',now()),
  ('9522aab2-ecf2-5be2-85c0-cde147faabf9','Ultrasonido de vías urinarias','ultrasonido de vias urinarias','synonym',1,'approved','Resolver benchmark v2: preserves urinary-tract scope.',now()),
  ('2320fe5b-df22-53ac-af3f-664c5ef4e950','RM de columna cervical','rm de columna cervical','abbreviation',1,'approved','Resolver benchmark v2: preserves MRI and cervical scope.',now()),
  ('c99af777-ed67-57a5-af35-1dcadc817b5a','Resonancia de columna lumbar o lumbosacra','resonancia de columna lumbar o lumbosacra','synonym',1,'approved','Resolver benchmark v2: preserves lumbar/lumbosacral scope.',now()),
  ('df10e6cc-e7bc-58df-be1c-2e2215c654be','RM de cráneo','rm de craneo','abbreviation',1,'approved','Resolver benchmark v2: preserves cranial scope.',now()),
  ('66313107-633f-52b0-ba8e-fa37b89d996c','RM de cuello','rm de cuello','abbreviation',1,'approved','Resolver benchmark v2: preserves neck scope.',now()),
  ('14afdb4a-9681-5b9a-8d4e-04a7b0d95b4e','Resonancia mamaria simple','resonancia mamaria simple','synonym',1,'approved','Resolver benchmark v2: preserves simple breast scope.',now()),
  ('7bca5f0e-f879-5c55-82c6-bdd03543227e','TAC de columna cervical simple','tac de columna cervical simple','abbreviation',1,'approved','Resolver benchmark v2: preserves simple cervical CT scope.',now()),
  ('6cf56af2-aa88-5ff9-b627-4507f1476048','TAC de columna lumbar simple','tac de columna lumbar simple','abbreviation',1,'approved','Resolver benchmark v2: preserves simple lumbar CT scope.',now()),
  ('6d4175a9-e365-5241-8859-c2f97a70c0d7','TAC de cráneo simple','tac de craneo simple','abbreviation',1,'approved','Resolver benchmark v2: preserves simple cranial CT scope.',now()),
  ('fef75fa2-4ca9-558b-b52e-f38a31c7685f','TAC de órbitas simple','tac de orbitas simple','abbreviation',1,'approved','Resolver benchmark v2: preserves simple orbit CT scope.',now()),
  ('d585766d-3502-5745-b5d6-7f2e2b1d8a65','TAC de senos paranasales simple','tac de senos paranasales simple','abbreviation',1,'approved','Resolver benchmark v2: preserves simple sinus CT scope.',now()),
  ('3b8beb63-d709-541e-941f-83a739dba3ea','TAC de abdomen superior simple','tac de abdomen superior simple','abbreviation',1,'approved','Resolver benchmark v2: preserves simple upper-abdomen CT scope.',now()),
  ('bbc0edbc-d4b7-5987-8aa3-5057fc5a864f','TAC de abdomen superior con contraste','tac de abdomen superior con contraste','abbreviation',1,'approved','Resolver benchmark v2: preserves contrast upper-abdomen CT scope.',now()),
  ('a43d2047-89f1-50c5-99e1-c0d006fe13f4','TAC de abdomen inferior simple','tac de abdomen inferior simple','abbreviation',1,'approved','Resolver benchmark v2: preserves simple lower-abdomen CT scope.',now()),
  ('5418efe4-d4d0-5cdb-bedf-689a04a518c8','TAC de abdomen inferior con contraste','tac de abdomen inferior con contraste','abbreviation',1,'approved','Resolver benchmark v2: preserves contrast lower-abdomen CT scope.',now()),
  ('b53fc6f3-4d51-5a8a-b919-cec0ddbbc66a','Radiografía abdomen AP de pie','radiografia abdomen ap de pie','synonym',1,'approved','Resolver benchmark v2: preserves standing AP projection.',now()),
  ('22258a25-fb19-549a-a729-ddf198e8d266','Radiografía de abdomen de pie y decúbito','radiografia de abdomen de pie y decubito','synonym',1,'approved','Resolver benchmark v2: preserves standing/decubitus projections.',now()),
  ('e8028e0a-a6b0-5100-b70c-b90a667a1847','Radiografía abdomen dos proyecciones AP y lateral','radiografia abdomen dos proyecciones ap y lateral','synonym',1,'approved','Resolver benchmark v2: preserves two-view projections.',now()),
  ('c8389561-8169-5e30-bf4d-e91d05371f17','Estudio de colposcopia','estudio de colposcopia','synonym',1,'approved','Resolver benchmark v2: preserves procedure identity.',now())
on conflict do nothing;

commit;
