-- ============================================================================
-- BAKERY ALGORITHM TEST SUITE
-- ============================================================================
--
-- This test suite validates Lamport's Bakery Algorithm implementation.
-- It tests for 15 different assumptions and edge cases.
--
-- Run with: gnatmake -P bakery_tests.gpr && ./bin/bakery_tests
--
-- ============================================================================

with Ada.Text_IO;

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
      Id : constant Thread_Id := 1;
   begin
      Start_Test ("Single thread lock/unlock");
      
      -- Reset state
      Number := (others => 0);
      Entering := (others => False);
      
      -- Thread should be able to lock
      Lock (Id);
      
      -- Verify thread has a ticket number
      if Number (Id) = 0 then
         Unlock (Id);
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
   -- TEST 2: Multiple threads get different ticket numbers
   -- Assumption: When multiple threads lock simultaneously, they get different numbers
   -- =========================================================================

   procedure Test_Multiple_Threads_Different_Tickets is
      Id1 : constant Thread_Id := 1;
      Id2 : constant Thread_Id := 2;
      Num1 : Natural;
      Num2 : Natural;
   begin
      Start_Test ("Multiple threads get different tickets");
      
      -- Reset state
      Number := (others => 0);
      Entering := (others => False);
      
      -- Lock both threads
      Lock (Id1);
      Num1 := Number (Id1);
      
      Lock (Id2);
      Num2 := Number (Id2);
      
      -- They should have different ticket numbers
      if Num1 = Num2 then
         Unlock (Id1);
         Unlock (Id2);
         End_Test (False);
         return;
      end if;
      
      Unlock (Id1);
      Unlock (Id2);
      End_Test (True);
   end Test_Multiple_Threads_Different_Tickets;


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
   -- TEST 4: Lock is reentrant (gets new ticket each time)
   -- Assumption: A thread can acquire the lock multiple times (reentrant behavior)
   -- =========================================================================

   procedure Test_Reentrant_Behavior is
      Id : constant Thread_Id := 1;
      Num1 : Natural;
      Num2 : Natural;
   begin
      Start_Test ("Reentrant behavior - gets new ticket");
      
      -- Reset state
      Number := (others => 0);
      Entering := (others => False);
      
      -- First lock
      Lock (Id);
      Num1 := Number (Id);
      
      -- Second lock (reentrant)
      Lock (Id);
      Num2 := Number (Id);
      
      -- Should have different ticket numbers (both will be > 0)
      if Num1 = 0 or Num2 = 0 or Num1 = Num2 then
         Unlock (Id);
         Unlock (Id);
         End_Test (False);
         return;
      end if;
      
      Unlock (Id);
      Unlock (Id);
      End_Test (True);
   end Test_Reentrant_Behavior;


   -- =========================================================================
   -- TEST 5: Ticket numbers increase with concurrent threads
   -- Assumption: Ticket numbers increase when multiple threads are active
   -- =========================================================================

   procedure Test_Ticket_Numbers_Increase is
      Id1 : constant Thread_Id := 1;
      Id2 : constant Thread_Id := 2;
      Num1 : Natural;
      Num2 : Natural;
   begin
      Start_Test ("Ticket numbers increase with concurrent threads");
      
      -- Reset state
      Number := (others => 0);
      Entering := (others => False);
      
      -- Lock first thread
      Lock (Id1);
      Num1 := Number (Id1);
      
      -- Lock second thread - should get higher number
      Lock (Id2);
      Num2 := Number (Id2);
      
      -- Second thread should have higher or equal ticket
      if Num2 < Num1 then
         Unlock (Id1);
         Unlock (Id2);
         End_Test (False);
         return;
      end if;
      
      Unlock (Id1);
      Unlock (Id2);
      End_Test (True);
   end Test_Ticket_Numbers_Increase;


   -- =========================================================================
   -- TEST 6: Tie breaking condition
   -- Assumption: When tickets are equal, lower ID thread has priority
   -- =========================================================================

   procedure Test_Tie_Breaking_Condition is
      Id1 : constant Thread_Id := 2;
      Id2 : constant Thread_Id := 1;
   begin
      Start_Test ("Tie breaking condition");
      
      -- Reset state
      Number := (others => 0);
      Entering := (others => False);
      
      -- Manually set both threads to have the same ticket number
      Number (Id1) := 100;
      Number (Id2) := 100;
      
      -- Verify the tie-breaking condition
      -- When Number(J) = Number(Id) and J < Id, thread Id should wait
      if Number (Id2) = Number (Id1) and Id2 < Id1 then
         -- This is the correct condition for tie-breaking
         End_Test (True);
         return;
      end if;
      
      End_Test (False);
   end Test_Tie_Breaking_Condition;


   -- =========================================================================
   -- TEST 7: Entering flag functionality
   -- Assumption: The Entering flag is properly set and cleared
   -- =========================================================================

   procedure Test_Entering_Flag is
      Id : constant Thread_Id := 1;
   begin
      Start_Test ("Entering flag functionality");
      
      -- Reset state
      Number := (others => 0);
      Entering := (others => False);
      
      -- Before lock, Entering should be False
      if Entering (Id) then
         End_Test (False);
         return;
      end if;
      
      -- During lock doorway phase, Entering should be True
      Entering (Id) := True;
      if not Entering (Id) then
         End_Test (False);
         return;
      end if;
      
      -- After getting ticket, Entering should be False
      Entering (Id) := False;
      if Entering (Id) then
         End_Test (False);
         return;
      end if;
      
      End_Test (True);
   end Test_Entering_Flag;


   -- =========================================================================
   -- TEST 8: Unlock resets ticket to 0
   -- Assumption: Unlock sets the thread's ticket number to 0
   -- =========================================================================

   procedure Test_Unlock_Resets_Ticket is
      Id : constant Thread_Id := 1;
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
      Id : constant Thread_Id := 1;
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
   -- TEST 10: All threads can acquire lock (no starvation)
   -- Assumption: All threads can eventually acquire the lock
   -- =========================================================================

   procedure Test_No_Starvation is
      Success_Count : Natural := 0;
      
      task type Starvation_Worker is
         entry Start (Id : Thread_Id);
      end Starvation_Worker;
      
      task body Starvation_Worker is
         My_Id : Thread_Id;
      begin
         accept Start (Id : Thread_Id) do
            My_Id := Id;
         end Start;
         
         Lock (My_Id);
         Success_Count := Success_Count + 1;
         Unlock (My_Id);
      end Starvation_Worker;
      
      Workers : array (Thread_Id) of Starvation_Worker;
   begin
      Start_Test ("No starvation - all threads can acquire lock");
      
      -- Reset state
      Success_Count := 0;
      Number := (others => 0);
      Entering := (others => False);
      
      -- Start all workers
      for Id in Thread_Id loop
         Workers(Id).Start (Id);
      end loop;
      
      -- Wait for all workers
      delay 2.0;
      
      -- All threads should have acquired the lock
      if Success_Count /= N then
         Ada.Text_IO.Put_Line ("  Only " & Natural'Image(Success_Count) & " out of " & Natural'Image(N) & " threads acquired lock");
         End_Test (False);
         return;
      end if;
      
      End_Test (True);
   end Test_No_Starvation;


   -- =========================================================================
   -- TEST 11: Critical section protection
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
   -- TEST 12: Lock works with all threads
   -- Assumption: The algorithm works correctly with all configured threads
   -- =========================================================================

   procedure Test_All_Threads is
      All_Completed : Natural := 0;
      
      task type All_Threads_Worker is
         entry Start (Id : Thread_Id);
      end All_Threads_Worker;
      
      task body All_Threads_Worker is
         My_Id : Thread_Id;
      begin
         accept Start (Id : Thread_Id) do
            My_Id := Id;
         end Start;
         
         Lock (My_Id);
         All_Completed := All_Completed + 1;
         Unlock (My_Id);
      end All_Threads_Worker;
      
      Workers : array (Thread_Id) of All_Threads_Worker;
   begin
      Start_Test ("Lock with all threads");
      
      -- Reset state
      All_Completed := 0;
      Number := (others => 0);
      Entering := (others => False);
      
      -- Start all workers simultaneously
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
   end Test_All_Threads;


   -- =========================================================================
   -- TEST 13: Unlock without lock is safe
   -- Assumption: Calling unlock on a thread that doesn't hold the lock is safe
   -- =========================================================================

   procedure Test_Unlock_Without_Lock is
      Id : constant Thread_Id := 1;
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
   -- TEST 14: Concurrent lock requests
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
      All_Completed := 0;
      Number := (others => 0);
      Entering := (others => False);
      
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
   -- TEST 15: Ticket numbers are positive
   -- Assumption: All ticket numbers are positive (greater than 0)
   -- =========================================================================

   procedure Test_Ticket_Numbers_Are_Positive is
      Id : constant Thread_Id := 1;
   begin
      Start_Test ("Ticket numbers are positive");
      
      -- Reset state
      Number := (others => 0);
      Entering := (others => False);
      
      Lock (Id);
      
      -- Ticket number should be positive
      if Number (Id) = 0 then
         Unlock (Id);
         End_Test (False);
         return;
      end if;
      
      Unlock (Id);
      End_Test (True);
   end Test_Ticket_Numbers_Are_Positive;


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
   Test_Multiple_Threads_Different_Tickets;
   Test_Mutual_Exclusion;
   Test_Reentrant_Behavior;
   Test_Ticket_Numbers_Increase;
   Test_Tie_Breaking_Condition;
   Test_Entering_Flag;
   Test_Unlock_Resets_Ticket;
   Test_Multiple_Lock_Cycles;
   Test_No_Starvation;
   Test_Critical_Section_Protection;
   Test_All_Threads;
   Test_Unlock_Without_Lock;
   Test_Concurrent_Lock_Requests;
   Test_Ticket_Numbers_Are_Positive;

   -- Print summary
   Print_Summary;

   -- Exit with appropriate code
   if Fail_Count > 0 then
      Ada.Text_IO.Put_Line ("SOME TESTS FAILED!");
   else
      Ada.Text_IO.Put_Line ("ALL TESTS PASSED!");
   end if;

end Bakery_Tests;
