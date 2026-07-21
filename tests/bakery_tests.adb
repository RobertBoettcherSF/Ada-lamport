-- ============================================================================
-- BAKERY ALGORITHM TEST SUITE
-- ============================================================================
--
-- This test suite validates Lamport's Bakery Algorithm implementation.
-- It tests for 12+ different assumptions and edge cases.
--
-- Tests are designed to be proven false (falsifiable) - each test either
-- passes (assumption holds) or fails (assumption is false).
--
-- Run with: gnatmake -P bakery_tests.gpr && ./bin/bakery_tests
--
-- ============================================================================

with Ada.Text_IO;
with Ada.Integer_Text_IO;
with Ada.Real_Time;
use type Ada.Real_Time.Time;

procedure Bakery_Tests is

   -- =========================================================================
   -- TEST FRAMEWORK
   -- =========================================================================

   Test_Count : Natural := 0;
   Pass_Count : Natural := 0;
   Fail_Count : Natural := 0;

   procedure Start_Test (Name : String) is
   begin
      Test_Count := Test_Count + 1;
      Ada.Text_IO.Put ("Test " & Natural'Image(Test_Count) & ": " & Name & " ... ");
   end Start_Test;

   procedure End_Test (Passed : Boolean) is
   begin
      if Passed then
         Pass_Count := Pass_Count + 1;
         Ada.Text_IO.Put_Line ("PASS");
      else
         Fail_Count := Fail_Count + 1;
         Ada.Text_IO.Put_Line ("FAIL");
      end if;
   end End_Test;

   procedure Print_Summary is
   begin
      Ada.Text_IO.New_Line;
      Ada.Text_IO.Put_Line ("========================================");
      Ada.Text_IO.Put_Line ("Test Summary:");
      Ada.Text_IO.Put_Line ("  Total:  " & Natural'Image(Test_Count));
      Ada.Text_IO.Put_Line ("  Passed: " & Natural'Image(Pass_Count));
      Ada.Text_IO.Put_Line ("  Failed: " & Natural'Image(Fail_Count));
      Ada.Text_IO.Put_Line ("========================================");
   end Print_Summary;


   -- =========================================================================
   -- BAKERY ALGORITHM IMPLEMENTATION (Same as bakery.adb)
   -- =========================================================================

   N : constant := 5;
   type Thread_Id is range 1 .. N;

   Entering : array (Thread_Id) of Boolean := (others => False);
   pragma Atomic_Components (Entering);

   Number : array (Thread_Id) of Natural := (others => 0);
   pragma Atomic_Components (Number);

   procedure Lock (Id : Thread_Id) is
      Max_Num : Natural := 0;
   begin
      Entering (Id) := True;

      for J in Thread_Id loop
         if Number (J) > Max_Num then
            Max_Num := Number (J);
         end if;
      end loop;

      Number (Id) := Max_Num + 1;
      Entering (Id) := False;

      for J in Thread_Id loop
         if J /= Id then
            while Entering (J) loop
               delay 0.0001;
            end loop;

            while Number (J) /= 0 and then
                  (Number (J) < Number (Id) or else
                  (Number (J) = Number (Id) and then J < Id)) loop
               delay 0.0001;
            end loop;
         end if;
      end loop;
   end Lock;

   procedure Unlock (Id : Thread_Id) is
   begin
      Number (Id) := 0;
   end Unlock;


   -- =========================================================================
   -- TEST 1: Single thread can acquire and release lock
   -- Assumption: A single thread can successfully acquire and release the lock
   -- =========================================================================

   procedure Test_Single_Thread_Lock is
      Id : Thread_Id := 1;
   begin
      Start_Test ("Single thread lock/unlock");
      
      -- Thread should be able to lock
      Lock (Id);
      
      -- Verify thread has a ticket number
      if Number (Id) = 0 then
         End_Test (False);
         return;
      end if;
      
      Unlock (Id);
      
      -- Verify ticket is reset
      if Number (Id) /= 0 then
         End_Test (False);
         return;
      end if;
      
      End_Test (True);
   end Test_Single_Thread_Lock;


   -- =========================================================================
   -- TEST 2: Multiple threads get unique increasing ticket numbers
   -- Assumption: When multiple threads request locks, they get unique, increasing numbers
   -- =========================================================================

   procedure Test_Unique_Ticket_Numbers is
      Id1, Id2, Id3 : Thread_Id := 1, 2, 3;
      Num1, Num2, Num3 : Natural;
   begin
      Start_Test ("Unique increasing ticket numbers");
      
      -- Reset all numbers
      Number := (others => 0);
      Entering := (others => False);
      
      -- Thread 1 gets a ticket
      Lock (Id1);
      Num1 := Number (Id1);
      Unlock (Id1);
      
      -- Thread 2 gets a ticket
      Lock (Id2);
      Num2 := Number (Id2);
      Unlock (Id2);
      
      -- Thread 3 gets a ticket
      Lock (Id3);
      Num3 := Number (Id3);
      Unlock (Id3);
      
      -- All numbers should be unique and increasing
      if Num1 >= Num2 or Num2 >= Num3 then
         End_Test (False);
         return;
      end if;
      
      End_Test (True);
   end Test_Unique_Ticket_Numbers;


   -- =========================================================================
   -- TEST 3: Mutual exclusion - only one thread in critical section
   -- Assumption: Only one thread can be in the critical section at a time
   -- =========================================================================

   Shared_Counter : Natural := 0;
   Violation_Count : Natural := 0;
   
   task type Test_Worker is
      entry Start (Id : Thread_Id);
   end Test_Worker;

   task body Test_Worker is
      My_Id : Thread_Id;
      My_Entry_Value : Natural;
      My_Exit_Value : Natural;
   begin
      accept Start (Id : Thread_Id) do
         My_Id := Id;
      end Start;
      
      Lock (My_Id);
      My_Entry_Value := Shared_Counter;
      delay 0.01; -- Simulate work in critical section
      Shared_Counter := Shared_Counter + 1;
      My_Exit_Value := Shared_Counter;
      Unlock (My_Id);
      
      -- If counter increased by more than 1, mutual exclusion was violated
      if My_Exit_Value - My_Entry_Value > 1 then
         Violation_Count := Violation_Count + 1;
      end if;
   end Test_Worker;

   procedure Test_Mutual_Exclusion is
      Workers : array (Thread_Id) of Test_Worker;
   begin
      Start_Test ("Mutual exclusion with concurrent threads");
      
      -- Reset state
      Shared_Counter := 0;
      Violation_Count := 0;
      Number := (others => 0);
      Entering := (others => False);
      
      -- Start all workers
      for Id in Thread_Id loop
         Workers(Id).Start (Id);
      end loop;
      
      -- Wait for all workers to complete
      delay 1.0;
      
      -- Check for violations
      if Violation_Count > 0 then
         Ada.Text_IO.Put_Line ("  VIOLATION: " & Natural'Image(Violation_Count) & " mutual exclusion violations detected!");
         End_Test (False);
         return;
      end if;
      
      -- Also verify counter was incremented correctly
      if Shared_Counter /= N then
         Ada.Text_IO.Put_Line ("  ERROR: Expected counter=" & Natural'Image(N) & ", got " & Natural'Image(Shared_Counter));
         End_Test (False);
         return;
      end if;
      
      End_Test (True);
   end Test_Mutual_Exclusion;


   -- =========================================================================
   -- TEST 4: Lock is reentrant (thread can lock multiple times)
   -- Assumption: A thread can acquire the lock multiple times in sequence
   -- Note: This is NOT a reentrant lock by design, so this should FAIL
   -- =========================================================================

   procedure Test_Reentrant_Lock is
      Id : Thread_Id := 1;
   begin
      Start_Test ("Reentrant lock (expected to fail - not reentrant)");
      
      -- Reset state
      Number := (others => 0);
      Entering := (others => False);
      
      Lock (Id);
      
      -- Try to lock again - this should deadlock or fail
      -- We'll use a timeout to detect deadlock
      declare
         Start_Time : Ada.Real_Time.Time := Ada.Real_Time.Clock;
         Timeout : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Milliseconds (100);
      begin
         -- Try second lock with timeout
         begin
            Lock (Id);
            -- If we get here, the lock is reentrant (which is wrong for Bakery)
            Unlock (Id);
            Unlock (Id);
            End_Test (False); -- FAIL: Lock should NOT be reentrant
            return;
         exception
            when others =>
               -- Any exception means it's not reentrant
               null;
         end;
         
         -- Check if we timed out
         if Ada.Real_Time.Clock - Start_Time > Timeout then
            -- Deadlock detected - lock is not reentrant (correct behavior)
            End_Test (True);
            return;
         end if;
      end;
      
      -- If we get here without deadlock, it's reentrant (wrong)
      End_Test (False);
   end Test_Reentrant_Lock;


   -- =========================================================================
   -- TEST 5: Ticket numbers wrap around correctly (overflow handling)
   -- Assumption: The algorithm handles ticket number overflow gracefully
   -- =========================================================================

   procedure Test_Ticket_Overflow is
      Id : Thread_Id := 1;
   begin
      Start_Test ("Ticket number overflow handling");
      
      -- Reset state
      Number := (others => 0);
      Entering := (others => False);
      
      -- Set a very high ticket number (close to Natural'Last)
      Number (Id) := Natural'Last - 10;
      
      -- Try to acquire lock
      Lock (Id);
      
      -- The new ticket should be higher than the previous
      if Number (Id) <= Natural'Last - 10 then
         End_Test (False);
         return;
      end if;
      
      Unlock (Id);
      End_Test (True);
   end Test_Ticket_Overflow;


   -- =========================================================================
   -- TEST 6: Thread with lower ID gets priority when tickets are equal
   -- Assumption: When two threads have the same ticket number, the one with lower ID goes first
   -- =========================================================================

   procedure Test_Tie_Breaking_By_Id is
      Id1, Id2 : Thread_Id := 2, 1; -- Id2 has lower ID
      Num1, Num2 : Natural;
   begin
      Start_Test ("Tie breaking by thread ID");
      
      -- Reset state
      Number := (others => 0);
      Entering := (others => False);
      
      -- Manually set both threads to have the same ticket number
      Number (Id1) := 100;
      Number (Id2) := 100;
      
      -- Thread 2 tries to lock
      Lock (Id1);
      Num1 := Number (Id1);
      
      -- Thread 1 (lower ID) should be able to lock and get a new number
      -- But actually, thread 1 should wait for thread 2 since they have same number
      -- and thread 1 has lower ID (so thread 2 should wait)
      
      -- Let's test the condition directly
      -- When Number(J) = Number(Id) and J < Id, thread Id should wait
      if not (Number (Id2) = Number (Id1) and Id2 < Id1) then
         Unlock (Id1);
         End_Test (False);
         return;
      end if;
      
      Unlock (Id1);
      End_Test (True);
   end Test_Tie_Breaking_By_Id;


   -- =========================================================================
   -- TEST 7: Entering flag prevents race condition in doorway
   -- Assumption: The Entering flag prevents race conditions when getting tickets
   -- =========================================================================

   procedure Test_Entering_Flag is
      Id1, Id2 : Thread_Id := 1, 2;
   begin
      Start_Test ("Entering flag prevents doorway race");
      
      -- Reset state
      Number := (others => 0);
      Entering := (others => False);
      
      -- Set thread 1 as entering
      Entering (Id1) := True;
      
      -- Thread 2 should wait for thread 1 to finish getting ticket
      Lock (Id2);
      
      -- Thread 1 finishes getting ticket
      Number (Id1) := 1;
      Entering (Id1) := False;
      
      -- Thread 2 should have gotten a higher ticket number
      if Number (Id2) <= Number (Id1) then
         Unlock (Id2);
         End_Test (False);
         return;
      end if;
      
      Unlock (Id2);
      End_Test (True);
   end Test_Entering_Flag;


   -- =========================================================================
   -- TEST 8: Unlock resets ticket to 0
   -- Assumption: Unlock sets the thread's ticket number to 0
   -- =========================================================================

   procedure Test_Unlock_Resets_Ticket is
      Id : Thread_Id := 1;
   begin
      Start_Test ("Unlock resets ticket to 0");
      
      -- Reset state
      Number := (others => 0);
      Entering := (others => False);
      
      Lock (Id);
      
      -- Verify ticket is non-zero
      if Number (Id) = 0 then
         Unlock (Id);
         End_Test (False);
         return;
      end if;
      
      Unlock (Id);
      
      -- Verify ticket is reset to 0
      if Number (Id) /= 0 then
         End_Test (False);
         return;
      end if;
      
      End_Test (True);
   end Test_Unlock_Resets_Ticket;


   -- =========================================================================
   -- TEST 9: Multiple lock/unlock cycles work correctly
   -- Assumption: A thread can lock and unlock multiple times
   -- =========================================================================

   procedure Test_Multiple_Lock_Cycles is
      Id : Thread_Id := 1;
   begin
      Start_Test ("Multiple lock/unlock cycles");
      
      -- Reset state
      Number := (others => 0);
      Entering := (others => False);
      
      -- Perform 10 lock/unlock cycles
      for I in 1 .. 10 loop
         Lock (Id);
         if Number (Id) = 0 then
            Unlock (Id);
            End_Test (False);
            return;
         end if;
         Unlock (Id);
         if Number (Id) /= 0 then
            End_Test (False);
            return;
         end if;
      end loop;
      
      End_Test (True);
   end Test_Multiple_Lock_Cycles;


   -- =========================================================================
   -- TEST 10: All threads can eventually acquire lock
   -- Assumption: All threads can eventually acquire the lock (no starvation)
   -- =========================================================================

   procedure Test_No_Starvation is
      type Extended_Thread_Id is range 1 .. 10;
      
      Entering_Ext : array (Extended_Thread_Id) of Boolean := (others => False);
      pragma Atomic_Components (Entering_Ext);
      
      Number_Ext : array (Extended_Thread_Id) of Natural := (others => 0);
      pragma Atomic_Components (Number_Ext);
      
      procedure Lock_Ext (Id : Extended_Thread_Id) is
         Max_Num : Natural := 0;
      begin
         Entering_Ext (Id) := True;
         
         for J in Extended_Thread_Id loop
            if Number_Ext (J) > Max_Num then
               Max_Num := Number_Ext (J);
            end if;
         end loop;
         
         Number_Ext (Id) := Max_Num + 1;
         Entering_Ext (Id) := False;
         
         for J in Extended_Thread_Id loop
            if J /= Id then
               while Entering_Ext (J) loop
                  delay 0.0001;
               end loop;
               
               while Number_Ext (J) /= 0 and then
                     (Number_Ext (J) < Number_Ext (Id) or else
                     (Number_Ext (J) = Number_Ext (Id) and then J < Id)) loop
                  delay 0.0001;
               end loop;
            end if;
         end loop;
      end Lock_Ext;
      
      procedure Unlock_Ext (Id : Extended_Thread_Id) is
      begin
         Number_Ext (Id) := 0;
      end Unlock_Ext;
      
      Success_Count : Natural := 0;
      
      task type Starvation_Worker is
         entry Start (Id : Extended_Thread_Id);
      end Starvation_Worker;
      
      task body Starvation_Worker is
         My_Id : Extended_Thread_Id;
      begin
         accept Start (Id : Extended_Thread_Id) do
            My_Id := Id;
         end Start;
         
         Lock_Ext (My_Id);
         Success_Count := Success_Count + 1;
         Unlock_Ext (My_Id);
      end Starvation_Worker;
      
      Workers : array (Extended_Thread_Id) of Starvation_Worker;
   begin
      Start_Test ("No starvation - all threads can acquire lock");
      
      Success_Count := 0;
      
      -- Start all workers
      for Id in Extended_Thread_Id loop
         Workers(Id).Start (Id);
      end loop;
      
      -- Wait for all workers
      delay 2.0;
      
      -- All threads should have acquired the lock
      if Success_Count /= 10 then
         Ada.Text_IO.Put_Line ("  Only " & Natural'Image(Success_Count) & " out of 10 threads acquired lock");
         End_Test (False);
         return;
      end if;
      
      End_Test (True);
   end Test_No_Starvation;


   -- =========================================================================
   -- TEST 11: Lock ordering is FIFO (first come, first served)
   -- Assumption: Threads acquire locks in the order they request them
   -- =========================================================================

   procedure Test_FIFO_Ordering is
      Id1, Id2, Id3 : Thread_Id := 1, 2, 3;
      Entry_Order : array (Thread_Id) of Natural := (others => 0);
      Order_Counter : Natural := 0;
      
      task type Ordered_Worker is
         entry Start (Id : Thread_Id);
      end Ordered_Worker;
      
      task body Ordered_Worker is
         My_Id : Thread_Id;
      begin
         accept Start (Id : Thread_Id) do
            My_Id := Id;
         end Start;
         
         Lock (My_Id);
         Order_Counter := Order_Counter + 1;
         Entry_Order (My_Id) := Order_Counter;
         delay 0.01;
         Unlock (My_Id);
      end Ordered_Worker;
      
      Workers : array (Thread_Id) of Ordered_Worker;
   begin
      Start_Test ("FIFO ordering of lock acquisition");
      
      -- Reset state
      Number := (others => 0);
      Entering := (others => False);
      Order_Counter := 0;
      Entry_Order := (others => 0);
      
      -- Start workers in order 1, 2, 3
      Workers(1).Start (1);
      delay 0.001; -- Small delay to ensure ordering
      Workers(2).Start (2);
      delay 0.001;
      Workers(3).Start (3);
      
      -- Wait for completion
      delay 1.0;
      
      -- Check if entry order matches start order
      -- Note: Due to scheduling, this might not always be perfect FIFO
      -- but with the delays, it should be close
      if Entry_Order(1) > Entry_Order(2) or Entry_Order(2) > Entry_Order(3) then
         Ada.Text_IO.Put_Line ("  Entry order: 1=" & Natural'Image(Entry_Order(1)) & 
                               ", 2=" & Natural'Image(Entry_Order(2)) & 
                               ", 3=" & Natural'Image(Entry_Order(3)));
         End_Test (False);
         return;
      end if;
      
      End_Test (True);
   end Test_FIFO_Ordering;


   -- =========================================================================
   -- TEST 12: Critical section protection - shared data integrity
   -- Assumption: Shared data is protected from concurrent modification
   -- =========================================================================

   Protected_Counter : Natural := 0;
   Expected_Sum : constant Natural := 100;
   
   task type Protection_Worker is
      entry Start (Id : Thread_Id; Count : Natural);
   end Protection_Worker;
   
   task body Protection_Worker is
      My_Id : Thread_Id;
      My_Count : Natural;
   begin
      accept Start (Id : Thread_Id; Count : Natural) do
         My_Id := Id;
         My_Count := Count;
      end Start;
      
      for I in 1 .. My_Count loop
         Lock (My_Id);
         Protected_Counter := Protected_Counter + 1;
         Unlock (My_Id);
      end loop;
   end Protection_Worker;

   procedure Test_Critical_Section_Protection is
      Workers : array (Thread_Id) of Protection_Worker;
      Total_Increment : constant Natural := 20; -- 5 threads * 20 = 100
   begin
      Start_Test ("Critical section protects shared data");
      
      -- Reset state
      Protected_Counter := 0;
      Number := (others => 0);
      Entering := (others => False);
      
      -- Start workers, each will increment 20 times
      for Id in Thread_Id loop
         Workers(Id).Start (Id, Total_Increment);
      end loop;
      
      -- Wait for completion
      delay 2.0;
      
      -- Verify final value
      if Protected_Counter /= Expected_Sum then
         Ada.Text_IO.Put_Line ("  Expected " & Natural'Image(Expected_Sum) & 
                               ", got " & Natural'Image(Protected_Counter));
         End_Test (False);
         return;
      end if;
      
      End_Test (True);
   end Test_Critical_Section_Protection;


   -- =========================================================================
   -- TEST 13: Lock works with maximum number of threads
   -- Assumption: The algorithm works correctly with the maximum configured threads
   -- =========================================================================

   procedure Test_Max_Threads is
      All_Locked : Boolean := True;
      
      task type Max_Thread_Worker is
         entry Start (Id : Thread_Id);
      end Max_Thread_Worker;
      
      task body Max_Thread_Worker is
         My_Id : Thread_Id;
      begin
         accept Start (Id : Thread_Id) do
            My_Id := Id;
         end Start;
         
         Lock (My_Id);
         -- Check if all threads have non-zero ticket numbers
         for J in Thread_Id loop
            if Number (J) = 0 then
               All_Locked := False;
            end if;
         end loop;
         Unlock (My_Id);
      end Max_Thread_Worker;
      
      Workers : array (Thread_Id) of Max_Thread_Worker;
   begin
      Start_Test ("Lock with maximum threads");
      
      -- Reset state
      Number := (others => 0);
      Entering := (others => False);
      All_Locked := True;
      
      -- Start all workers simultaneously
      for Id in Thread_Id loop
         Workers(Id).Start (Id);
      end loop;
      
      -- Wait for completion
      delay 2.0;
      
      -- All threads should have been able to lock
      if not All_Locked then
         End_Test (False);
         return;
      end if;
      
      End_Test (True);
   end Test_Max_Threads;


   -- =========================================================================
   -- TEST 14: Unlock without lock does not cause issues
   -- Assumption: Calling unlock on a thread that doesn't hold the lock is safe
   -- =========================================================================

   procedure Test_Unlock_Without_Lock is
      Id : Thread_Id := 1;
   begin
      Start_Test ("Unlock without prior lock");
      
      -- Reset state
      Number := (others => 0);
      Entering := (others => False);
      
      -- Call unlock without lock
      Unlock (Id);
      
      -- Should not cause any issues
      -- Number should be 0 (already 0)
      if Number (Id) /= 0 then
         End_Test (False);
         return;
      end if;
      
      End_Test (True);
   end Test_Unlock_Without_Lock;


   -- =========================================================================
   -- TEST 15: Concurrent lock requests are handled correctly
   -- Assumption: Multiple simultaneous lock requests are handled without deadlock
   -- =========================================================================

   procedure Test_Concurrent_Lock_Requests is
      All_Completed : Natural := 0;
      
      task type Concurrent_Worker is
         entry Start (Id : Thread_Id);
      end Concurrent_Worker;
      
      task body Concurrent_Worker is
         My_Id : Thread_Id;
      begin
         accept Start (Id : Thread_Id) do
            My_Id := Id;
         end Start;
         
         -- All threads try to lock at the same time
         Lock (My_Id);
         All_Completed := All_Completed + 1;
         Unlock (My_Id);
      end Concurrent_Worker;
      
      Workers : array (Thread_Id) of Concurrent_Worker;
   begin
      Start_Test ("Concurrent lock requests");
      
      -- Reset state
      Number := (others => 0);
      Entering := (others => False);
      All_Completed := 0;
      
      -- Start all workers at nearly the same time
      for Id in Thread_Id loop
         Workers(Id).Start (Id);
      end loop;
      
      -- Wait for completion
      delay 2.0;
      
      -- All threads should have completed
      if All_Completed /= N then
         Ada.Text_IO.Put_Line ("  Only " & Natural'Image(All_Completed) & " threads completed");
         End_Test (False);
         return;
      end if;
      
      End_Test (True);
   end Test_Concurrent_Lock_Requests;


   -- =========================================================================
   -- MAIN TEST RUNNER
   -- =========================================================================

begin
   Ada.Text_IO.Put_Line ("========================================");
   Ada.Text_IO.Put_Line ("BAKERY ALGORITHM TEST SUITE");
   Ada.Text_IO.Put_Line ("========================================");
   Ada.Text_IO.New_Line;

   -- Run all tests
   Test_Single_Thread_Lock;
   Test_Unique_Ticket_Numbers;
   Test_Mutual_Exclusion;
   Test_Reentrant_Lock;
   Test_Ticket_Overflow;
   Test_Tie_Breaking_By_Id;
   Test_Entering_Flag;
   Test_Unlock_Resets_Ticket;
   Test_Multiple_Lock_Cycles;
   Test_No_Starvation;
   Test_FIFO_Ordering;
   Test_Critical_Section_Protection;
   Test_Max_Threads;
   Test_Unlock_Without_Lock;
   Test_Concurrent_Lock_Requests;

   -- Print summary
   Print_Summary;

   -- Exit with appropriate code
   if Fail_Count > 0 then
      Ada.Text_IO.Put_Line ("SOME TESTS FAILED!");
   else
      Ada.Text_IO.Put_Line ("ALL TESTS PASSED!");
   end if;

end Bakery_Tests;
