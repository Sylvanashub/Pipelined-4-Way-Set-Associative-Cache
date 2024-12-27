module cache (
    input   logic           clk,
    input   logic           rst,

    // cpu side signals, ufp -> upward facing port
    input   logic   [31:0]  ufp_addr,
    input   logic   [3:0]   ufp_rmask,
    input   logic   [3:0]   ufp_wmask,
    output  logic   [31:0]  ufp_rdata,
    input   logic   [31:0]  ufp_wdata,
    output  logic           ufp_resp,

    // memory side signals, dfp -> downward facing port
    output  logic   [31:0]  dfp_addr,
    output  logic           dfp_read,
    output  logic           dfp_write,
    input   logic   [255:0] dfp_rdata,
    output  logic   [255:0] dfp_wdata,
    input   logic           dfp_resp
);

localparam  IDLE     = 3'H0 ;
localparam  CMP_TAG  = 3'H2 ;
localparam  RESP     = 3'H3 ;
localparam  ALLOCATE = 3'H4 ;
localparam  UPDATE   = 3'H5 ;
localparam  STALL    = 3'H6 ;
localparam  WR_BACK  = 3'H7 ;

logic [2:0] state_r ;
logic [2:0] state_nxt ;

logic [31:0]   ufp_addr_r  ;
logic [31:0]   ufp_wdata_r ;
logic [3:0]    ufp_wmask_r ;
logic [3:0]    ufp_rmask_r ;
wire ufp_ready ;

logic [3:0]    ufp_addr_set  ;
//logic [22:0]   ufp_addr_tag        ;
//logic [2:0]    ufp_addr_offset   ;
logic [3:0]    ufp_addr_set_r  ;
logic [22:0]   ufp_addr_tag_r        ;
logic [2:0]    ufp_addr_offset_r   ;
logic [255:0]  data_out       ;

//logic [255:0]  dfp_wdata_r    ;
logic [31:0]   dfp_addr_r     ;

assign ufp_addr_set     = ufp_addr[8:5] ;
//assign ufp_addr_tag     = ufp_addr[31:9] ;
//assign ufp_addr_offset  = ufp_addr[4:2] ;

assign ufp_addr_set_r   = ufp_addr_r[8:5] ;
assign ufp_addr_tag_r   = ufp_addr_r[31:9] ;
assign ufp_addr_offset_r= ufp_addr_r[4:2] ;


logic       cache_line_csb ;
logic       cache_line_rd ;
logic [3:0] cache_line_addr ;
logic [3:0] cache_line_web ;

logic [3:0] update_write ;
logic [3:0] allocate_write ;

logic [255:0]  cache_data_out [0:3] ;
logic [255:0]  cache_data_din  ;
logic [31:0]   cache_data_wmask ;
logic [23:0]   cache_tag_out  [0:3] ;
logic [23:0]   cache_tag_din  ;
logic [3:0]    cache_valid_out ;

logic [3:0]    way_hit     ;
logic [3:0]    way_dirty   ;
logic          hit         ;
logic          dirty       ;
logic [3:0]    hit_write   ;


logic [2:0]    plru_cur ;
logic [2:0]    plru_nxt ;
logic [3:0]    way_sel  ;
logic [3:0]    way_sel_r;

logic [1:0] way_num ;

assign way_num =  ((state_r == WR_BACK || state_r == ALLOCATE) ? way_sel_r[3] : way_sel[3]) ? 2'H3 :
                  ((state_r == WR_BACK || state_r == ALLOCATE) ? way_sel_r[2] : way_sel[2]) ? 2'H2 :
                  ((state_r == WR_BACK || state_r == ALLOCATE) ? way_sel_r[1] : way_sel[1]) ? 2'H1 :
                  ((state_r == WR_BACK || state_r == ALLOCATE) ? way_sel_r[0] : way_sel[0]) ? 2'H0 : 2'H0 ;

//------------------------------------------------------------------------------
// ufp signal 
//------------------------------------------------------------------------------

assign ufp_ready = ((state_r == IDLE) || ufp_resp) ;
always_ff@(posedge clk)
begin
   if( rst )
   begin
      ufp_addr_r <= '0 ;
      ufp_wdata_r <= '0 ;
      ufp_rmask_r <= '0 ;
      ufp_wmask_r <= '0 ;
   end
   else if(ufp_ready)
   begin
      ufp_addr_r <= ufp_addr ;
      ufp_wdata_r <= ufp_wdata ;
      ufp_rmask_r <= ufp_rmask ;
      ufp_wmask_r <= ufp_wmask ;
   end
end

assign ufp_rdata= data_out[ ufp_addr_offset_r*32 +: 32] ;
assign ufp_resp = (state_r == CMP_TAG) && hit || state_r == RESP ;

//------------------------------------------------------------------------------
// Main state machine
//------------------------------------------------------------------------------

always_ff@(posedge clk)
begin
   if( rst )
      state_r <= IDLE ;
   else
      state_r <= state_nxt ;
end

wire ufp_access_valid =  |ufp_rmask || |ufp_wmask ;

always_comb
begin
   state_nxt = state_r ;
   unique case( state_r )
   IDLE : 
   begin
      if( ufp_access_valid )
         state_nxt = CMP_TAG ;
   end
   CMP_TAG :
   begin
      if( hit )
      begin
         if( |ufp_wmask_r )
            state_nxt = STALL ;
         else if( ~ufp_access_valid )
            state_nxt = IDLE ;
      end
      else
      begin
         state_nxt = dirty ? WR_BACK : ALLOCATE ;
      end
   end
   ALLOCATE :
      if( dfp_resp )
         state_nxt = UPDATE ;
   UPDATE :
      state_nxt = RESP ;
   RESP :
      if( |ufp_wmask_r )
         state_nxt = STALL ;
      else if( ufp_access_valid )
         state_nxt = CMP_TAG ;
      else
         state_nxt = IDLE ;
   STALL :
      if( |ufp_rmask_r || |ufp_wmask_r )
         state_nxt = CMP_TAG ;
      else
         state_nxt = IDLE ;
   WR_BACK:
      if( dfp_resp )
         state_nxt = ALLOCATE ;
   default :
      state_nxt = state_r ;
   endcase
end





//------------------------------------------------------------------------------
// DFP
//------------------------------------------------------------------------------
//always_ff@(posedge clk)
//begin
//   if( rst )
//   begin
//      dfp_wdata_r <= '0 ;
//   end
//   else if( state_r == CMP_TAG && dirty )
//   begin
//      dfp_wdata_r <= cache_data_out[way_num] ;
//      dfp_wdata_r[ufp_addr_offset_r*32+:32] <= ufp_wdata_r ;
//   end
//end

always_ff@(posedge clk)
begin
   if( rst )
      dfp_addr_r <= '0 ;
   else if( ufp_ready )
      dfp_addr_r <= {ufp_addr[31:5],5'H00} ;
   else if( state_r == CMP_TAG && dirty )
      dfp_addr_r[31:9] <= cache_tag_out[way_num][22:0] ;
   else if( state_r == WR_BACK && dfp_resp )
      dfp_addr_r[31:9] <= ufp_addr_r[31:9] ;
end

assign dfp_addr[8:0] =  dfp_addr_r[8:0] ;
assign dfp_addr[31:9] = dirty ? cache_tag_out[way_num][22:0] : dfp_addr_r[31:9] ;

assign dfp_read = (state_r == ALLOCATE) || (( state_r == CMP_TAG) && ~hit && ~dirty) ;
assign dfp_write = dirty || (state_r == WR_BACK ) ;
assign dfp_wdata =  cache_data_out[way_num] ;

//always_comb
//begin
//   if( dirty )
//   begin
//      dfp_wdata = cache_data_out[way_num] ;
//      dfp_wdata[ufp_addr_offset_r*32+:32] = ufp_wdata_r ;
//   end
//   else
//   begin
//      dfp_wdata = dfp_wdata_r ;
//   end
//end


//------------------------------------------------------------------------------
// Cache state signals
//------------------------------------------------------------------------------

assign hit     = |way_hit  ;
//assign dirty   = ~hit && cache_valid_out[way_num] & way_dirty[way_num] & |ufp_wmask_r & (state_r == CMP_TAG );
assign dirty   = ~hit && cache_valid_out[way_num] & way_dirty[way_num] & (state_r == CMP_TAG );
assign data_out = ({256{way_hit[0]||(way_sel_r[0]&&state_r==RESP)}} & cache_data_out[0]) |
                  ({256{way_hit[1]||(way_sel_r[1]&&state_r==RESP)}} & cache_data_out[1]) |
                  ({256{way_hit[2]||(way_sel_r[2]&&state_r==RESP)}} & cache_data_out[2]) |
                  ({256{way_hit[3]||(way_sel_r[3]&&state_r==RESP)}} & cache_data_out[3]) ;



assign way_sel[0] = plru_cur[1:0] == 2'B00 ;
assign way_sel[1] = plru_cur[1:0] == 2'B10 ;
assign way_sel[2] = {plru_cur[2],plru_cur[0]} == 2'B01 ;
assign way_sel[3] = {plru_cur[2],plru_cur[0]} == 2'B11 ;

always_ff@(posedge clk)
begin
   if( rst )
      way_sel_r <= '0 ;
   else if( state_r == CMP_TAG  )
      way_sel_r <= way_sel ;
end

//------------------------------------------------------------------------------
// Cache line control
//------------------------------------------------------------------------------
assign cache_line_rd  = state_r == IDLE || state_r == RESP ||
                        (state_r == CMP_TAG && hit && |ufp_rmask_r ) ||  
                        (state_r == STALL && (|ufp_rmask_r || |ufp_wmask_r)) ;
assign cache_line_csb = ~cache_line_rd & (&cache_line_web) ;

always_comb
begin
   cache_line_addr = ufp_addr_set_r ;
   unique case( state_r )
   IDLE,
   RESP:  cache_line_addr = ufp_addr_set ;
   //CMP_TAG: cache_line_addr = hit && |ufp_wmask_r ? ufp_addr_set_r : ufp_addr_set ;
   CMP_TAG: cache_line_addr = |hit_write ? ufp_addr_set_r : ufp_addr_set ;
   default: cache_line_addr = ufp_addr_set_r ;
   endcase
end

assign cache_tag_din = {(|hit_write)||(|update_write),ufp_addr_tag_r} ;
assign cache_data_din = (|hit_write)||(|update_write) ? {8{ufp_wdata_r}} : dfp_rdata ;

always_comb
begin
   if( (|hit_write) || (|update_write) )
   begin
      //cache_data_wmask = {{28{1'H0}},ufp_wmask_r} << {ufp_addr_offset_r,2'H0} ;
   unique case( ufp_addr_offset_r )
   3'H0 : cache_data_wmask = {{28{1'H0}},ufp_wmask_r,{ 0{1'H0}}} ;
   3'H1 : cache_data_wmask = {{24{1'H0}},ufp_wmask_r,{ 4{1'H0}}} ;
   3'H2 : cache_data_wmask = {{20{1'H0}},ufp_wmask_r,{ 8{1'H0}}} ;
   3'H3 : cache_data_wmask = {{16{1'H0}},ufp_wmask_r,{12{1'H0}}} ;
   3'H4 : cache_data_wmask = {{12{1'H0}},ufp_wmask_r,{16{1'H0}}} ;
   3'H5 : cache_data_wmask = {{ 8{1'H0}},ufp_wmask_r,{20{1'H0}}} ;
   3'H6 : cache_data_wmask = {{ 4{1'H0}},ufp_wmask_r,{24{1'H0}}} ;
   3'H7 : cache_data_wmask = {{ 0{1'H0}},ufp_wmask_r,{28{1'H0}}} ;
   endcase
   end
   else
   begin
      cache_data_wmask = '1 ;
   end
end

    generate for (genvar i = 0; i < 4; i++) begin : arrays
        mp_cache_data_array data_array (
            .clk0       ( clk                ),
            .csb0       ( cache_line_csb     ),
            .web0       ( cache_line_web[i]  ),
            .wmask0     ( cache_data_wmask   ),
            .addr0      ( cache_line_addr    ),
            .din0       ( cache_data_din     ),
            .dout0      ( cache_data_out[i]  )
        );
        mp_cache_tag_array tag_array (
            .clk0       ( clk                ),
            .csb0       ( cache_line_csb     ),
            .web0       ( cache_line_web[i]  ),
            .addr0      ( cache_line_addr    ),
            .din0       ( cache_tag_din      ),
            .dout0      ( cache_tag_out[i]   )
        );
        valid_array valid_array (
            .clk0       ( clk                ),
            .rst0       ( rst                ),
            .csb0       ( 1'H0               ),
            .web0       ( ~allocate_write[i] ),
            .addr0      ( cache_line_addr    ),
            .din0       ( 1'H1               ),
            .dout0      ( cache_valid_out[i] )
        );

        assign way_hit[i] = (state_r == CMP_TAG) && cache_valid_out[i] && (cache_tag_out[i][22:0] == ufp_addr_tag_r) ;
//        assign stall_way_hit[i] = (state_r == STALL) && cache_valid_out[i] && (cache_tag_out[i][22:0] == ufp_addr_tag_r) ;
        assign way_dirty[i] = cache_tag_out[i][23] ;

   //assign cache_line_web[i] = ~((state_r == ALLOCATE) && dfp_resp && way_sel[i]) ;
   assign update_write[i]  = ((state_r == UPDATE) && |ufp_wmask_r && way_sel_r[i]) ;
   assign allocate_write[i]= ((state_r == ALLOCATE) && dfp_resp && way_sel_r[i]) ;
   assign hit_write[i]     = way_hit[i] && |ufp_wmask_r ;
   assign cache_line_web[i]= ~(allocate_write[i] | hit_write[i] | update_write[i]) ;

    end endgenerate

//------------------------------------------------------------------------------
// PLRU
//------------------------------------------------------------------------------

logic       lru_rp_csb  ;
logic       lru_rp_web  ;
logic [3:0] lru_rp_addr ;
logic [2:0] lru_rp_din  ;
logic [2:0] lru_rp_dout ;

logic       lru_wp_csb  ;
logic       lru_wp_web  ;
logic [3:0] lru_wp_addr ;
logic [2:0] lru_wp_din  ;
logic [2:0] lru_wp_dout ;

always_comb
begin
   plru_nxt = plru_cur ;
   if( hit )
   begin
      unique case( way_hit )
      4'B0001 : plru_nxt = {plru_cur[2],2'B11} ;
      4'B0010 : plru_nxt = {plru_cur[2],2'B01} ;
      4'B0100 : plru_nxt = {1'B1,plru_cur[1],1'B0} ;
      4'B1000 : plru_nxt = {1'B0,plru_cur[1],1'B0} ;
      default : plru_nxt = plru_cur ;
      endcase
   end
   else
   begin
      casez( plru_cur ) 
      3'B?00 : plru_nxt = {plru_cur[2],2'B11} ;
      3'B?10 : plru_nxt = {plru_cur[2],2'B01} ;
      3'B0?1 : plru_nxt = {1'B1,plru_cur[1],1'B0} ;
      3'B1?1 : plru_nxt = {1'B0,plru_cur[1],1'B0} ;
      default: plru_nxt = plru_cur ;
      endcase
   end
end

assign lru_rp_csb = ~cache_line_rd ;
assign lru_rp_web = '1 ;
assign lru_rp_addr= cache_line_addr;
assign lru_rp_din = '0 ;
//assign plru_cur   = (lru_rp_addr == lru_wp_addr && ~lru_rp_csb && ~lru_wp_web ) ? lru_wp_din : lru_rp_dout ;
assign plru_cur   = lru_rp_dout ;


assign lru_wp_csb = '0 ;
//assign lru_wp_web = &cache_line_web & (~hit) ;
assign lru_wp_web = ~(state_r == CMP_TAG) ;
assign lru_wp_addr= ufp_addr_set_r ; 
assign lru_wp_din = plru_nxt  ;


    lru_array lru_array (
        .clk0       ( clk  ),
        .rst0       ( rst  ),
        
        .csb0       ( lru_rp_csb    ),
        .web0       ( lru_rp_web    ),
        .addr0      ( lru_rp_addr   ),
        .din0       ( lru_rp_din    ),
        .dout0      ( lru_rp_dout   ),

        .csb1       ( lru_wp_csb    ),
        .web1       ( lru_wp_web    ),
        .addr1      ( lru_wp_addr   ),
        .din1       ( lru_wp_din    ),
        .dout1      ( lru_wp_dout   )
    );

endmodule
