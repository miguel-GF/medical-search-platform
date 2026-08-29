-- Generated from a reviewed LOINC mapping fixture.
-- Do not edit manually; regenerate after reviewer approval.
begin;
do $$
begin
  if not exists (
    select 1
    from catalog.items i
    join health.services s on s.catalog_item_id = i.id
    where i.id = '00000000-0000-0000-0000-000000001103'::uuid
      and i.status = 'active'
      and s.service_type in ('lab_test', 'lab_panel')
  ) then
    raise exception 'LOINC mapping target is not an active laboratory service: %', '00000000-0000-0000-0000-000000001103';
  end if;
end;
$$;
insert into catalog.item_identifiers (item_id, system, code, version, mapping_type, status, source_note, verified, approved_at) values ('00000000-0000-0000-0000-000000001103', 'http://loinc.org', '58410-2', '2.83', 'exact', 'active', 'LOINC 2.83 exact mapping; CBC panel by automated count reviewed against canonical Biometria hematica.', true, now()) on conflict (item_id, system, code, version) do update set mapping_type = excluded.mapping_type, status = excluded.status, source_note = excluded.source_note, verified = excluded.verified, approved_at = excluded.approved_at;
insert into health.lab_service_definitions (service_id, component, property, time_aspect, system, scale_type, method, order_observation, loinc_version, verified, source_note) values ('00000000-0000-0000-0000-000000001103', 'Complete blood count panel', '-', 'Pt', 'Bld', '-', 'Automated count', 'order', '2.83', true, 'LOINC 2.83 exact mapping; CBC panel by automated count reviewed against canonical Biometria hematica.') on conflict (service_id) do update set component = coalesce(excluded.component, health.lab_service_definitions.component), property = coalesce(excluded.property, health.lab_service_definitions.property), time_aspect = coalesce(excluded.time_aspect, health.lab_service_definitions.time_aspect), system = coalesce(excluded.system, health.lab_service_definitions.system), scale_type = coalesce(excluded.scale_type, health.lab_service_definitions.scale_type), method = coalesce(excluded.method, health.lab_service_definitions.method), order_observation = coalesce(excluded.order_observation, health.lab_service_definitions.order_observation), loinc_version = excluded.loinc_version, verified = excluded.verified, source_note = excluded.source_note;
do $$
begin
  if not exists (
    select 1
    from catalog.items i
    join health.services s on s.catalog_item_id = i.id
    where i.id = '00000000-0000-0000-0000-000000001104'::uuid
      and i.status = 'active'
      and s.service_type in ('lab_test', 'lab_panel')
  ) then
    raise exception 'LOINC mapping target is not an active laboratory service: %', '00000000-0000-0000-0000-000000001104';
  end if;
end;
$$;
insert into catalog.item_identifiers (item_id, system, code, version, mapping_type, status, source_note, verified, approved_at) values ('00000000-0000-0000-0000-000000001104', 'http://loinc.org', '24356-8', '2.83', 'exact', 'active', 'LOINC 2.83 exact mapping; complete urinalysis panel reviewed against canonical Examen general de orina.', true, now()) on conflict (item_id, system, code, version) do update set mapping_type = excluded.mapping_type, status = excluded.status, source_note = excluded.source_note, verified = excluded.verified, approved_at = excluded.approved_at;
insert into health.lab_service_definitions (service_id, component, property, time_aspect, system, scale_type, method, order_observation, loinc_version, verified, source_note) values ('00000000-0000-0000-0000-000000001104', 'Urinalysis complete panel', '-', 'Pt', 'Urine', '-', null, 'order', '2.83', true, 'LOINC 2.83 exact mapping; complete urinalysis panel reviewed against canonical Examen general de orina.') on conflict (service_id) do update set component = coalesce(excluded.component, health.lab_service_definitions.component), property = coalesce(excluded.property, health.lab_service_definitions.property), time_aspect = coalesce(excluded.time_aspect, health.lab_service_definitions.time_aspect), system = coalesce(excluded.system, health.lab_service_definitions.system), scale_type = coalesce(excluded.scale_type, health.lab_service_definitions.scale_type), order_observation = coalesce(excluded.order_observation, health.lab_service_definitions.order_observation), loinc_version = excluded.loinc_version, verified = excluded.verified, source_note = excluded.source_note;
do $$
begin
  if not exists (
    select 1
    from catalog.items i
    join health.services s on s.catalog_item_id = i.id
    where i.id = '00000000-0000-0000-0000-000000001109'::uuid
      and i.status = 'active'
      and s.service_type in ('lab_test', 'lab_panel')
  ) then
    raise exception 'LOINC mapping target is not an active laboratory service: %', '00000000-0000-0000-0000-000000001109';
  end if;
end;
$$;
insert into catalog.item_identifiers (item_id, system, code, version, mapping_type, status, source_note, verified, approved_at) values ('00000000-0000-0000-0000-000000001109', 'http://loinc.org', '2345-7', '2.83', 'exact', 'active', 'LOINC 2.83 exact mapping; glucose mass concentration in serum/plasma.', true, now()) on conflict (item_id, system, code, version) do update set mapping_type = excluded.mapping_type, status = excluded.status, source_note = excluded.source_note, verified = excluded.verified, approved_at = excluded.approved_at;
insert into health.lab_service_definitions (service_id, component, property, time_aspect, system, scale_type, method, order_observation, loinc_version, verified, source_note) values ('00000000-0000-0000-0000-000000001109', 'Glucose', 'MCnc', 'Pt', 'Ser/Plas', 'Qn', null, 'both', '2.83', true, 'LOINC 2.83 exact mapping; glucose mass concentration in serum/plasma.') on conflict (service_id) do update set component = coalesce(excluded.component, health.lab_service_definitions.component), property = coalesce(excluded.property, health.lab_service_definitions.property), time_aspect = coalesce(excluded.time_aspect, health.lab_service_definitions.time_aspect), system = coalesce(excluded.system, health.lab_service_definitions.system), scale_type = coalesce(excluded.scale_type, health.lab_service_definitions.scale_type), order_observation = coalesce(excluded.order_observation, health.lab_service_definitions.order_observation), loinc_version = excluded.loinc_version, verified = excluded.verified, source_note = excluded.source_note;
do $$
begin
  if not exists (
    select 1
    from catalog.items i
    join health.services s on s.catalog_item_id = i.id
    where i.id = '00000000-0000-0000-0000-000000001110'::uuid
      and i.status = 'active'
      and s.service_type in ('lab_test', 'lab_panel')
  ) then
    raise exception 'LOINC mapping target is not an active laboratory service: %', '00000000-0000-0000-0000-000000001110';
  end if;
end;
$$;
insert into catalog.item_identifiers (item_id, system, code, version, mapping_type, status, source_note, verified, approved_at) values ('00000000-0000-0000-0000-000000001110', 'http://loinc.org', '2160-0', '2.83', 'exact', 'active', 'LOINC 2.83 exact mapping; creatinine mass concentration in serum/plasma.', true, now()) on conflict (item_id, system, code, version) do update set mapping_type = excluded.mapping_type, status = excluded.status, source_note = excluded.source_note, verified = excluded.verified, approved_at = excluded.approved_at;
insert into health.lab_service_definitions (service_id, component, property, time_aspect, system, scale_type, method, order_observation, loinc_version, verified, source_note) values ('00000000-0000-0000-0000-000000001110', 'Creatinine', 'MCnc', 'Pt', 'Ser/Plas', 'Qn', null, 'both', '2.83', true, 'LOINC 2.83 exact mapping; creatinine mass concentration in serum/plasma.') on conflict (service_id) do update set component = coalesce(excluded.component, health.lab_service_definitions.component), property = coalesce(excluded.property, health.lab_service_definitions.property), time_aspect = coalesce(excluded.time_aspect, health.lab_service_definitions.time_aspect), system = coalesce(excluded.system, health.lab_service_definitions.system), scale_type = coalesce(excluded.scale_type, health.lab_service_definitions.scale_type), order_observation = coalesce(excluded.order_observation, health.lab_service_definitions.order_observation), loinc_version = excluded.loinc_version, verified = excluded.verified, source_note = excluded.source_note;
do $$
begin
  if not exists (
    select 1
    from catalog.items i
    join health.services s on s.catalog_item_id = i.id
    where i.id = '00000000-0000-0000-0000-000000001111'::uuid
      and i.status = 'active'
      and s.service_type in ('lab_test', 'lab_panel')
  ) then
    raise exception 'LOINC mapping target is not an active laboratory service: %', '00000000-0000-0000-0000-000000001111';
  end if;
end;
$$;
insert into catalog.item_identifiers (item_id, system, code, version, mapping_type, status, source_note, verified, approved_at) values ('00000000-0000-0000-0000-000000001111', 'http://loinc.org', '3016-3', '2.83', 'exact', 'active', 'LOINC 2.83 exact mapping; thyrotropin units per volume in serum/plasma.', true, now()) on conflict (item_id, system, code, version) do update set mapping_type = excluded.mapping_type, status = excluded.status, source_note = excluded.source_note, verified = excluded.verified, approved_at = excluded.approved_at;
insert into health.lab_service_definitions (service_id, component, property, time_aspect, system, scale_type, method, order_observation, loinc_version, verified, source_note) values ('00000000-0000-0000-0000-000000001111', 'Thyrotropin', 'ACnc', 'Pt', 'Ser/Plas', 'Qn', null, 'both', '2.83', true, 'LOINC 2.83 exact mapping; thyrotropin units per volume in serum/plasma.') on conflict (service_id) do update set component = coalesce(excluded.component, health.lab_service_definitions.component), property = coalesce(excluded.property, health.lab_service_definitions.property), time_aspect = coalesce(excluded.time_aspect, health.lab_service_definitions.time_aspect), system = coalesce(excluded.system, health.lab_service_definitions.system), scale_type = coalesce(excluded.scale_type, health.lab_service_definitions.scale_type), order_observation = coalesce(excluded.order_observation, health.lab_service_definitions.order_observation), loinc_version = excluded.loinc_version, verified = excluded.verified, source_note = excluded.source_note;
do $$
begin
  if not exists (
    select 1
    from catalog.items i
    join health.services s on s.catalog_item_id = i.id
    where i.id = '00000000-0000-0000-0000-000000001112'::uuid
      and i.status = 'active'
      and s.service_type in ('lab_test', 'lab_panel')
  ) then
    raise exception 'LOINC mapping target is not an active laboratory service: %', '00000000-0000-0000-0000-000000001112';
  end if;
end;
$$;
insert into catalog.item_identifiers (item_id, system, code, version, mapping_type, status, source_note, verified, approved_at) values ('00000000-0000-0000-0000-000000001112', 'http://loinc.org', '3024-7', '2.83', 'exact', 'active', 'LOINC 2.83 exact mapping; free thyroxine mass concentration in serum/plasma.', true, now()) on conflict (item_id, system, code, version) do update set mapping_type = excluded.mapping_type, status = excluded.status, source_note = excluded.source_note, verified = excluded.verified, approved_at = excluded.approved_at;
insert into health.lab_service_definitions (service_id, component, property, time_aspect, system, scale_type, method, order_observation, loinc_version, verified, source_note) values ('00000000-0000-0000-0000-000000001112', 'Thyroxine.free', 'MCnc', 'Pt', 'Ser/Plas', 'Qn', null, 'both', '2.83', true, 'LOINC 2.83 exact mapping; free thyroxine mass concentration in serum/plasma.') on conflict (service_id) do update set component = coalesce(excluded.component, health.lab_service_definitions.component), property = coalesce(excluded.property, health.lab_service_definitions.property), time_aspect = coalesce(excluded.time_aspect, health.lab_service_definitions.time_aspect), system = coalesce(excluded.system, health.lab_service_definitions.system), scale_type = coalesce(excluded.scale_type, health.lab_service_definitions.scale_type), order_observation = coalesce(excluded.order_observation, health.lab_service_definitions.order_observation), loinc_version = excluded.loinc_version, verified = excluded.verified, source_note = excluded.source_note;
do $$
begin
  if not exists (
    select 1
    from catalog.items i
    join health.services s on s.catalog_item_id = i.id
    where i.id = '00000000-0000-0000-0000-000000001113'::uuid
      and i.status = 'active'
      and s.service_type in ('lab_test', 'lab_panel')
  ) then
    raise exception 'LOINC mapping target is not an active laboratory service: %', '00000000-0000-0000-0000-000000001113';
  end if;
end;
$$;
insert into catalog.item_identifiers (item_id, system, code, version, mapping_type, status, source_note, verified, approved_at) values ('00000000-0000-0000-0000-000000001113', 'http://loinc.org', '3053-6', '2.83', 'exact', 'active', 'LOINC 2.83 exact mapping; total triiodothyronine mass concentration in serum/plasma.', true, now()) on conflict (item_id, system, code, version) do update set mapping_type = excluded.mapping_type, status = excluded.status, source_note = excluded.source_note, verified = excluded.verified, approved_at = excluded.approved_at;
insert into health.lab_service_definitions (service_id, component, property, time_aspect, system, scale_type, method, order_observation, loinc_version, verified, source_note) values ('00000000-0000-0000-0000-000000001113', 'Triiodothyronine', 'MCnc', 'Pt', 'Ser/Plas', 'Qn', null, 'both', '2.83', true, 'LOINC 2.83 exact mapping; total triiodothyronine mass concentration in serum/plasma.') on conflict (service_id) do update set component = coalesce(excluded.component, health.lab_service_definitions.component), property = coalesce(excluded.property, health.lab_service_definitions.property), time_aspect = coalesce(excluded.time_aspect, health.lab_service_definitions.time_aspect), system = coalesce(excluded.system, health.lab_service_definitions.system), scale_type = coalesce(excluded.scale_type, health.lab_service_definitions.scale_type), order_observation = coalesce(excluded.order_observation, health.lab_service_definitions.order_observation), loinc_version = excluded.loinc_version, verified = excluded.verified, source_note = excluded.source_note;
commit;
