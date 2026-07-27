-- You can use this file to load seed data into the database using SQL statements
insert into Member (id, name, email, phone_number) values (0, 'John Smith', 'john.smith@mailinator.com', '2125551212');
-- Seeded user is already activated (dashboard 12 login demos)
insert into AuthAccount (member_id, password, status, activation_token, token_expires_at, activated_at)
  values (0, 'demo', 'activated', null, null, 0);
