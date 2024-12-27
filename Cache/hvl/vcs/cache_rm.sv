module cache_rm (
    input   logic           clk,
    input   logic           rst,

    // cpu side signals, ufp -> upward facing port
    input   logic   [31:0]  ufp_addr,
    input   logic   [3:0]   ufp_rmask,
    input   logic   [3:0]   ufp_wmask,
    input   logic   [31:0]  ufp_rdata,
    input   logic   [31:0]  ufp_wdata,
    input   logic           ufp_resp,

    // memory side signals, dfp -> downward facing port
    input   logic   [31:0]  dfp_addr,
    input   logic           dfp_read,
    input   logic           dfp_write,
    input   logic   [255:0] dfp_rdata,
    input   logic   [255:0] dfp_wdata,
    input   logic           dfp_resp
);

localparam MEM_SIZE = 16384*8 ;
localparam ADDR_MSB = $clog2(MEM_SIZE*4) - 1 ;
logic [31:0] mem [MEM_SIZE] ;

wire _x = |ufp_wmask | |ufp_wdata | dfp_write | |dfp_wdata ;

//------------------------------------------------------------------------------
// Save dfp rdata into mem
//------------------------------------------------------------------------------
enum bit [1:0] {
   IDLE  ,
   READ  ,
   WRITE  
} ufp_state ;

logic [3:0] ufp_wmask_r ;
logic [31:0] ufp_wdata_r ;
logic [31:0] ufp_addr_r ;
   

always@(posedge clk)
begin
   //for miss
   if( dfp_read && dfp_resp )
   begin
      for(int i=0;i<8;i++)
      begin
         //mem[dfp_addr[31:2]+i] = dfp_rdata[i*32 +: 32] ;
         mem[dfp_addr[ADDR_MSB:2]+i] = dfp_rdata[i*32 +: 32] ;
         $display("@%t [DBG] mem[0x%x] = %x",$time(),(dfp_addr+i*4),dfp_rdata[i*32 +: 32]);
      end

      if( |ufp_wmask_r && (ufp_addr_r[31:5] == dfp_addr[31:5]) )
      begin
         
         if( ufp_wmask_r[0] ) mem[ufp_addr_r[ADDR_MSB:2]][ 0+:8] = ufp_wdata_r[ 0+:8] ;
         if( ufp_wmask_r[1] ) mem[ufp_addr_r[ADDR_MSB:2]][ 8+:8] = ufp_wdata_r[ 8+:8] ;
         if( ufp_wmask_r[2] ) mem[ufp_addr_r[ADDR_MSB:2]][16+:8] = ufp_wdata_r[16+:8] ;
         if( ufp_wmask_r[3] ) mem[ufp_addr_r[ADDR_MSB:2]][24+:8] = ufp_wdata_r[24+:8] ;
         $display("@%t [DBG] wb mem[0x%x] = %x",$time(),ufp_addr_r,ufp_wdata_r);

      end
   end

   //for hit
   if( |ufp_wmask && (ufp_resp || ufp_state == IDLE))
   begin
      if( ufp_wmask[0] ) mem[ufp_addr[ADDR_MSB:2]][ 0+:8] = ufp_wdata[ 0+:8] ;
      if( ufp_wmask[1] ) mem[ufp_addr[ADDR_MSB:2]][ 8+:8] = ufp_wdata[ 8+:8] ;
      if( ufp_wmask[2] ) mem[ufp_addr[ADDR_MSB:2]][16+:8] = ufp_wdata[16+:8] ;
      if( ufp_wmask[3] ) mem[ufp_addr[ADDR_MSB:2]][24+:8] = ufp_wdata[24+:8] ;
      $display("@%t [DBG] ufp_wr mem[0x%x] = %x",$time(),ufp_addr,ufp_wdata);
   end
end

always@(posedge clk)
begin
   if( dfp_write && dfp_resp )
   begin
      bit [255:0] bExp ;

      for(int i=0;i<8;i++)
      begin
         bExp[i*32+:32] = mem[dfp_addr[ADDR_MSB:2]+i] ;
      end

      if( bExp !== dfp_wdata )
      begin
         $error($sformatf("DFP Write[0x%x] = 0x%x , expect = 0x%x",
         dfp_addr,dfp_wdata,bExp));
         repeat(10)@(posedge clk);
         $finish();
      end
   end
end



always@(posedge clk)
begin
   if( rst )
      ufp_state <= IDLE ;
   else
   begin
      case( ufp_state )
      IDLE : 
      if( |ufp_rmask ) ufp_state <= READ ;
      else if( |ufp_wmask ) ufp_state <= WRITE ;

      READ ,
      WRITE: if( ufp_resp ) ufp_state <= |ufp_rmask ? READ : |ufp_wmask ? WRITE : IDLE ;
      endcase
   end
end

always@(posedge clk)
begin
   if(( ufp_state == IDLE && (|ufp_rmask || |ufp_wmask) ) || (( ufp_state == READ || ufp_state == WRITE )&& ufp_resp ))
   begin
      ufp_addr_r <= ufp_addr ;
      ufp_wmask_r <= ufp_wmask ;
      ufp_wdata_r <= ufp_wdata ;
   end
end

always@(negedge clk)
begin
   if( ufp_state == READ && ufp_resp )
   begin
      if( ufp_rdata !== mem[ufp_addr_r[ADDR_MSB:2]] )
      begin
         $error($sformatf("UFP Read[0x%x] = 0x%x , expect = 0x%x",
         ufp_addr_r,ufp_rdata,mem[ufp_addr_r[ADDR_MSB:2]]));
         repeat(10)@(posedge clk);
         $finish();
      end
   end
end

//------------------------------------------------------------------------------
// Cache model
//------------------------------------------------------------------------------

localparam CACHE_SET_NUM   = 16 ;
localparam CACHE_WAY_NUM   = 4 ;
localparam CACHE_DAT_NUM   = 8 ;

localparam CACHE_TAG_W  = 32 - $clog2(CACHE_SET_NUM) - $clog2(CACHE_DAT_NUM) -2 ;

typedef struct {

   logic [22:0]   tag ; //23
   logic [3:0]    set_idx ;   //4
   logic [2:0]    dat_idx ;   //3
   logic [1:0]    res ; //2

} stcCacheInfoType ;

typedef struct {

   logic way01_less ;  //1 : less
   logic way0_less  ;  
   logic way2_less  ;

} stcPLRUtype ;

typedef struct {

   logic [CACHE_WAY_NUM-1:0]     valid       ;
   logic [CACHE_TAG_W-1:0]       cache_tag   [CACHE_WAY_NUM];
   logic [CACHE_DAT_NUM*32-1:0]  cache_data  [CACHE_WAY_NUM];
   stcPLRUtype                   plru                       ;

} stcCacheType ;

bit cache_hit ;
int cache_rd_way ;
int cache_wr_way ;
stcCacheInfoType cache_info ;
stcCacheType     cache_sel ;



stcCacheType stcCache [CACHE_SET_NUM] ;

function stcCacheInfoType get_cache_info ( logic [31:0] addr ) ;

   {get_cache_info.tag,
   get_cache_info.set_idx,
   get_cache_info.dat_idx,
   get_cache_info.res} = addr ;

endfunction

function int get_wr_way ( stcPLRUtype plru );

   if( plru.way01_less )
   begin
      if( plru.way0_less )
         get_wr_way = 0 ;
      else
         get_wr_way = 1 ;
   end
   else
   begin
      if( plru.way2_less )
         get_wr_way = 2 ;
      else
         get_wr_way = 3 ;
   end

endfunction

function stcPLRUtype update_plru ( stcPLRUtype plru ) ;

   update_plru = plru ;

   if( cache_hit )
   begin
      if( cache_rd_way < 2 )
      begin
         update_plru.way01_less = 0 ;
         update_plru.way0_less = cache_rd_way == 0 ? 0 : 1 ;
      end
      else
      begin
         update_plru.way01_less = 1 ;
         update_plru.way2_less = cache_rd_way == 2 ? 0 : 1 ;
      end
   end
   else
   begin

      if( cache_wr_way < 2 )
      begin
         update_plru.way01_less = 0 ;
         update_plru.way0_less  = cache_wr_way == 0 ? 0 : 1 ;
      end
      else
      begin
         update_plru.way01_less = 1 ;
         update_plru.way2_less  = cache_wr_way == 2 ? 0 : 1 ;
      end

   end

endfunction

initial
begin
   for(int i=0;i<CACHE_SET_NUM;i++)
   begin
      stcCache[i].plru.way01_less = 1 ;
      stcCache[i].plru.way0_less  = 1 ;
      stcCache[i].plru.way2_less  = 1 ;

      for(int j=0;j<CACHE_WAY_NUM;j++)
      begin
         stcCache[i].valid[j] = '0 ;
         stcCache[i].cache_tag[j]  = '0 ;
         stcCache[i].cache_data[j] = '0 ;
      end

   end
end

task cache_read( logic [31:0] addr ) ;

cache_hit = 1'H0 ;

cache_info = get_cache_info( addr ) ;

cache_sel = stcCache[cache_info.set_idx] ;

for(int i=0;i<CACHE_WAY_NUM;i++)
begin
   if( cache_sel.cache_tag[i] == cache_info.tag &&  cache_sel.valid[i] == 1 )
   begin
      cache_hit = 1'H1 ;
      cache_rd_way = i ;
   end
end

if( ~cache_hit )
begin
   @(posedge dfp_resp);
   @(negedge clk );
   cache_wr_way = get_wr_way( cache_sel.plru ) ;
   stcCache[cache_info.set_idx].valid[cache_wr_way] = 1'H1 ;
   stcCache[cache_info.set_idx].cache_data[cache_wr_way] = dfp_rdata ;
   stcCache[cache_info.set_idx].cache_tag[cache_wr_way] = cache_info.tag ;
end

stcCache[cache_info.set_idx].plru = update_plru( cache_sel.plru ) ;

endtask

always@(posedge clk)
begin
   if(( ufp_state == IDLE && |ufp_rmask ) || ( ufp_state == READ && ufp_resp && |ufp_rmask ))
   begin
      cache_read( ufp_addr ) ;
   end
   else
   begin
      cache_hit = 1'H0 ;
   end
end


always@(negedge clk)
begin
   if( ufp_state == READ && ufp_resp && 0)
   begin
      if( dut.hit != cache_hit )
      begin
         $error("Cache hit mismatch , RTL hit = %x , RM hit = %x",
         dut.hit,cache_hit );
         repeat(2)@(posedge clk);
         $finish();
      end
   end
end

endmodule
