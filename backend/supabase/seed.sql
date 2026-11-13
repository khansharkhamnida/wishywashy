-- Sample laundromats and machines, the same ones the iOS app shows in sample mode.
--
-- Generated from ios/wishywashy/Services/Laundromats/PartnerLaundromats.swift and
-- ios/wishywashy/SampleData/SampleMachines.swift. If you change those, change this too.
--
-- Safe to run more than once: rows that already exist are left alone.
-- Machines that are "in use" are given a finish time counted from the moment you run this file.
-- There are no sample bookings, because a booking belongs to a signed-in user. Make some with book_machine().

insert into public.laundromats (id, name, address, lat, lng, rating) values
  ('l1', 'WishyWash Tampines', 'Blk 4 Tampines Street 11, Singapore', 1.3496, 103.9568, 4.5),
  ('l2', 'WishyWash Orchard', 'Somerset Road, Orchard, Singapore', 1.3048, 103.8318, 4.2),
  ('l3', 'WishyWash Jurong East', 'Jurong Gateway Road, Jurong East, Singapore', 1.3329, 103.7436, null),
  ('l4', 'WishyWash Bugis', 'Victoria Street, Bugis, Singapore', 1.3009, 103.8559, 3.8)
on conflict (id) do nothing;

insert into public.machines (id, laundromat_id, type, label, capacity_kg, status, price_minor, cycle_minutes, available_at) values
  ('w01', 'l1', 'washer', 'W01', 15, 'available', 600, 36, null),
  ('w02', 'l1', 'washer', 'W02', 15, 'in_use', 600, 36, now() + interval '18 minutes'),
  ('w03', 'l1', 'washer', 'W03', 15, 'available', 600, 36, null),
  ('w04', 'l1', 'washer', 'W04', 10, 'in_use', 500, 30, now() + interval '5 minutes'),
  ('d01', 'l1', 'dryer', 'D01', 18, 'available', 400, 40, null),
  ('d02', 'l1', 'dryer', 'D02', 18, 'available', 400, 40, null),
  ('w05', 'l1', 'washer', 'W05', 10, 'out_of_order', 500, 30, null),
  ('w06', 'l1', 'washer', 'W06', 15, 'in_use', 600, 36, null),
  ('d03', 'l1', 'dryer', 'D03', 18, 'in_use', 400, 40, now() + interval '8 minutes'),
  ('w01-l2', 'l2', 'washer', 'W01', 15, 'in_use', 800, 36, now() + interval '10 minutes'),
  ('w02-l2', 'l2', 'washer', 'W02', 15, 'in_use', 800, 36, now() + interval '12 minutes'),
  ('w03-l2', 'l2', 'washer', 'W03', 10, 'in_use', 600, 30, now() + interval '12 minutes'),
  ('w04-l2', 'l2', 'washer', 'W04', 10, 'in_use', 600, 30, now() + interval '25 minutes'),
  ('w05-l2', 'l2', 'washer', 'W05', 15, 'available', 800, 36, null),
  ('w06-l2', 'l2', 'washer', 'W06', 10, 'out_of_order', 600, 30, null),
  ('d01-l2', 'l2', 'dryer', 'D01', 18, 'in_use', 500, 40, now() + interval '16 minutes'),
  ('d02-l2', 'l2', 'dryer', 'D02', 18, 'in_use', 500, 40, now() + interval '8 minutes'),
  ('d03-l2', 'l2', 'dryer', 'D03', 18, 'available', 500, 40, null),
  ('d04-l2', 'l2', 'dryer', 'D04', 18, 'in_use', 500, 40, null),
  ('w01-l3', 'l3', 'washer', 'W01', 15, 'available', 400, 36, null),
  ('w02-l3', 'l3', 'washer', 'W02', 15, 'available', 400, 36, null),
  ('w03-l3', 'l3', 'washer', 'W03', 10, 'available', 300, 30, null),
  ('w04-l3', 'l3', 'washer', 'W04', 10, 'available', 300, 30, null),
  ('w05-l3', 'l3', 'washer', 'W05', 15, 'available', 400, 36, null),
  ('w06-l3', 'l3', 'washer', 'W06', 10, 'out_of_order', 300, 30, null),
  ('d01-l3', 'l3', 'dryer', 'D01', 18, 'available', 200, 40, null),
  ('d02-l3', 'l3', 'dryer', 'D02', 18, 'available', 200, 40, null),
  ('d03-l3', 'l3', 'dryer', 'D03', 18, 'available', 200, 40, null),
  ('d04-l3', 'l3', 'dryer', 'D04', 18, 'in_use', 200, 40, null),
  ('w01-l4', 'l4', 'washer', 'W01', 15, 'available', 600, 36, null),
  ('w02-l4', 'l4', 'washer', 'W02', 15, 'in_use', 600, 36, now() + interval '12 minutes'),
  ('w03-l4', 'l4', 'washer', 'W03', 10, 'available', 500, 30, null),
  ('w04-l4', 'l4', 'washer', 'W04', 10, 'in_use', 500, 30, now() + interval '25 minutes'),
  ('w05-l4', 'l4', 'washer', 'W05', 15, 'available', 600, 36, null),
  ('w06-l4', 'l4', 'washer', 'W06', 10, 'out_of_order', 500, 30, null),
  ('d01-l4', 'l4', 'dryer', 'D01', 18, 'available', 300, 40, null),
  ('d02-l4', 'l4', 'dryer', 'D02', 18, 'in_use', 300, 40, now() + interval '8 minutes'),
  ('d03-l4', 'l4', 'dryer', 'D03', 18, 'available', 300, 40, null),
  ('d04-l4', 'l4', 'dryer', 'D04', 18, 'in_use', 300, 40, null)
on conflict (id) do nothing;
