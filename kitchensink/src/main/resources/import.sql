-- You can use this file to load seed data into the database using SQL statements
insert into Member (id, name, email, phone_number) values (0, 'John Smith', 'john.smith@mailinator.com', '2125551212');
insert into AuthAccount (member_id, password, status, app_role, activation_token, token_expires_at, activated_at, recovery_token, recovery_expires_at) values (0, 'demo', 'activated', 'admin', null, null, 0, null, null);
insert into Member (id, name, email, phone_number) values (1, 'Jane Doe', 'jane.doe@mailinator.com', '2125552121');
insert into AuthAccount (member_id, password, status, app_role, activation_token, token_expires_at, activated_at, recovery_token, recovery_expires_at) values (1, 'demo', 'activated', 'member', null, null, 0, null, null);
