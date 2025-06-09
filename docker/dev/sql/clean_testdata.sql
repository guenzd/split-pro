-- Clean generated test data based on naming scheme
DO $$
DECLARE
BEGIN
  DELETE FROM "ExpenseParticipant"
  WHERE "expenseId" IN (
    SELECT id FROM "Expense"
    WHERE name LIKE 'Expense %'
  );

  DELETE FROM "ExpenseNote"
  WHERE "expenseId" IN (
    SELECT id FROM "Expense"
    WHERE name LIKE 'Expense %'
  );

  DELETE FROM "Expense"
  WHERE name LIKE 'Expense %';

  DELETE FROM "GroupUser"
  WHERE "groupId" IN (
    SELECT id FROM "Group"
    WHERE name LIKE 'Group %' OR "publicId" LIKE 'group_%'
  );

  DELETE FROM "Group"
  WHERE name LIKE 'Group %' OR "publicId" LIKE 'group_%';

  DELETE FROM "User"
  WHERE name LIKE 'User %';

END $$;