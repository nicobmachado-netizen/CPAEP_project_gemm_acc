//--------------------------
// Library of common tasks for any testbench
//--------------------------

// Time delays
task time_delay (input delay);
  begin
    #delay;
  end
endtask

// Clock delays
task clk_delay(
  input int delay
);
  begin
    for(int i=0; i < delay; i++) begin
      @(posedge clk_i);
    end
  end
  #1;
endtask

task clk_unit_delay();
  begin
    @(posedge clk_i);
  end
endtask
