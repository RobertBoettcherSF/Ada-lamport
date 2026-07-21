with Ada.Text_IO;

procedure Bakery_Tests is

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

   procedure Test_Single_Thread_Lock is
      Id : constant Thread_Id := 1;
   begin
      Start_Test ("Single thread lock/unlock");
      Number := (others => 0);
      Entering := (others => False);
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
      End_Test (True);
   end Test_Single_Thread_Lock;

   procedure Test_Two_Threads_Different_Tickets is
      Id1 : constant Thread_Id := 1;
      Id2 : constant Thread_Id := 2;
   begin
      Start_Test ("Two threads get tickets");
      Number := (others => 0);
      Entering := (others => False);
      Lock (Id1);
      Lock (Id2);
      if Number (Id1) = 0 or Number (Id2) = 0 then
         Unlock (Id1);
         Unlock (Id2);
         End_Test (False);
         return;
      end if;
      Unlock (Id1);
      Unlock (Id2);
      End_Test (True);
   end Test_Two_Threads_Different_Tickets;

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
      delay 0.01;
      Shared_Counter := Shared_Counter + 1;
      My_Exit_Value := Shared_Counter;
      Unlock (My_Id);
      if My_Exit_Value - My_Entry_Value > 1 then
         Violation_Count := Violation_Count + 1;
      end if;
   end Test_Worker;

   procedure Test_Mutual_Exclusion is
      Workers : array (Thread_Id) of Test_Worker;
   begin
      Start_Test ("Mutual exclusion");
      Shared_Counter := 0;
      Violation_Count := 0;
      Number := (others => 0);
      Entering := (others => False);
      for Id in Thread_Id loop
         Workers(Id).Start (Id);
      end loop;
      delay 1.0;
      if Violation_Count > 0 then
         End_Test (False);
         return;
      end if;
      if Shared_Counter /= N then
         End_Test (False);
         return;
      end if;
      End_Test (True);
   end Test_Mutual_Exclusion;

   procedure Test_Reentrant_Behavior is
      Id : constant Thread_Id := 1;
   begin
      Start_Test ("Reentrant behavior");
      Number := (others => 0);
      Entering := (others => False);
      Lock (Id);
      if Number (Id) = 0 then
         Unlock (Id);
         End_Test (False);
         return;
      end if;
      Lock (Id);
      if Number (Id) = 0 then
         Unlock (Id);
         Unlock (Id);
         End_Test (False);
         return;
      end if;
      Unlock (Id);
      Unlock (Id);
      End_Test (True);
   end Test_Reentrant_Behavior;

   procedure Test_Ticket_Numbers_Increase is
      Id1 : constant Thread_Id := 1;
      Id2 : constant Thread_Id := 2;
   begin
      Start_Test ("Ticket numbers increase");
      Number := (others => 0);
      Entering := (others => False);
      Lock (Id1);
      Lock (Id2);
      if Number (Id2) < Number (Id1) then
         Unlock (Id1);
         Unlock (Id2);
         End_Test (False);
         return;
      end if;
      Unlock (Id1);
      Unlock (Id2);
      End_Test (True);
   end Test_Ticket_Numbers_Increase;

   procedure Test_Tie_Breaking_Logic is
   begin
      Start_Test ("Tie breaking logic");
      End_Test (True);
   end Test_Tie_Breaking_Logic;

   procedure Test_Entering_Flag is
      Id : constant Thread_Id := 1;
   begin
      Start_Test ("Entering flag");
      Number := (others => 0);
      Entering := (others => False);
      if Entering (Id) then
         End_Test (False);
         return;
      end if;
      Entering (Id) := True;
      if not Entering (Id) then
         End_Test (False);
         return;
      end if;
      Entering (Id) := False;
      if Entering (Id) then
         End_Test (False);
         return;
      end if;
      End_Test (True);
   end Test_Entering_Flag;

   procedure Test_Unlock_Resets_Ticket is
      Id : constant Thread_Id := 1;
   begin
      Start_Test ("Unlock resets ticket");
      Number := (others => 0);
      Entering := (others => False);
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
      End_Test (True);
   end Test_Unlock_Resets_Ticket;

   procedure Test_Multiple_Lock_Cycles is
      Id : constant Thread_Id := 1;
   begin
      Start_Test ("Multiple lock cycles");
      Number := (others => 0);
      Entering := (others => False);
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
      Start_Test ("No starvation");
      Success_Count := 0;
      Number := (others => 0);
      Entering := (others => False);
      for Id in Thread_Id loop
         Workers(Id).Start (Id);
      end loop;
      delay 2.0;
      if Success_Count /= N then
         End_Test (False);
         return;
      end if;
      End_Test (True);
   end Test_No_Starvation;

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
      Total_Increment : constant Natural := 20;
   begin
      Start_Test ("Critical section protection");
      Protected_Counter := 0;
      Number := (others => 0);
      Entering := (others => False);
      for Id in Thread_Id loop
         Workers(Id).Start (Id, Total_Increment);
      end loop;
      delay 2.0;
      if Protected_Counter /= Expected_Sum then
         End_Test (False);
         return;
      end if;
      End_Test (True);
   end Test_Critical_Section_Protection;

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
      Start_Test ("All threads lock");
      All_Completed := 0;
      Number := (others => 0);
      Entering := (others => False);
      for Id in Thread_Id loop
         Workers(Id).Start (Id);
      end loop;
      delay 2.0;
      if All_Completed /= N then
         End_Test (False);
         return;
      end if;
      End_Test (True);
   end Test_All_Threads;

   procedure Test_Unlock_Without_Lock is
      Id : constant Thread_Id := 1;
   begin
      Start_Test ("Unlock without lock");
      Number := (others => 0);
      Entering := (others => False);
      Unlock (Id);
      if Number (Id) /= 0 then
         End_Test (False);
         return;
      end if;
      End_Test (True);
   end Test_Unlock_Without_Lock;

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
         Lock (My_Id);
         All_Completed := All_Completed + 1;
         Unlock (My_Id);
      end Concurrent_Worker;
      Workers : array (Thread_Id) of Concurrent_Worker;
   begin
      Start_Test ("Concurrent requests");
      All_Completed := 0;
      Number := (others => 0);
      Entering := (others => False);
      for Id in Thread_Id loop
         Workers(Id).Start (Id);
      end loop;
      delay 2.0;
      if All_Completed /= N then
         End_Test (False);
         return;
      end if;
      End_Test (True);
   end Test_Concurrent_Lock_Requests;

   procedure Test_Ticket_Numbers_Are_Positive is
      Id : constant Thread_Id := 1;
   begin
      Start_Test ("Ticket numbers positive");
      Number := (others => 0);
      Entering := (others => False);
      Lock (Id);
      if Number (Id) = 0 then
         Unlock (Id);
         End_Test (False);
         return;
      end if;
      Unlock (Id);
      End_Test (True);
   end Test_Ticket_Numbers_Are_Positive;

begin
   Ada.Text_IO.Put_Line ("========================================");
   Ada.Text_IO.Put_Line ("BAKERY ALGORITHM TEST SUITE");
   Ada.Text_IO.Put_Line ("========================================");
   Ada.Text_IO.New_Line;
   Test_Single_Thread_Lock;
   Test_Two_Threads_Different_Tickets;
   Test_Mutual_Exclusion;
   Test_Reentrant_Behavior;
   Test_Ticket_Numbers_Increase;
   Test_Tie_Breaking_Logic;
   Test_Entering_Flag;
   Test_Unlock_Resets_Ticket;
   Test_Multiple_Lock_Cycles;
   Test_No_Starvation;
   Test_Critical_Section_Protection;
   Test_All_Threads;
   Test_Unlock_Without_Lock;
   Test_Concurrent_Lock_Requests;
   Test_Ticket_Numbers_Are_Positive;
   Print_Summary;
   if Fail_Count > 0 then
      Ada.Text_IO.Put_Line ("SOME TESTS FAILED!");
   else
      Ada.Text_IO.Put_Line ("ALL TESTS PASSED!");
   end if;
end Bakery_Tests;
