//--------------------------------
// Design: cv32e40s_compare
// File Name: cv32e40s_compare.sv
// Function: Comparison module for cv32e40s dual core setup.  
// Coder: JarlMS
//--------------------------------

// Parameter is number of bits in concatenated bit-vector
module cv32e40s_compare
#(
    parameter int N = 4
 )
 (
    input logic [N-1:0] core_master,
    input logic [N-1:0] core_checker,
    output logic error 
);

    always_comb begin
        error = 0; // Initialize to false 
        // Comapre both inputs bit by bit 
        for (int i = 0; i < N-1; i++) begin
            if (core_master[i] !== core_checker[i]) begin 
                error = 1;
                break;
            end 
        end
    end

endmodule
