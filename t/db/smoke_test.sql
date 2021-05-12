
GRANT ALL PRIVILEGES ON `pf_smoke_test%`.* TO pf_smoke_tester@'%' IDENTIFIED BY 'packet' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON `pf_smoke_test%`.* TO pf_smoke_tester@'localhost' IDENTIFIED BY 'packet' WITH GRANT OPTION;
FLUSH PRIVILEGES;
