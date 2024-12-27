
module ufp_mst ;

wire #100 clk = top_tb.clk ;

task start_read ( int iAddr );

   @(posedge clk);
   ufp_itf.addr[0]   <= iAddr ;
   ufp_itf.rmask[0]  <= '1 ;
   ufp_itf.wmask[0]  <= '0 ;
   ufp_itf.wdata[0]  <= 'x ;
   @(posedge clk);
   ufp_itf.addr[0]   <= 'x ;
   ufp_itf.rmask[0]  <= 'x ;
   ufp_itf.wmask[0]  <= '0 ;
   ufp_itf.wdata[0]  <= 'x ;

endtask


task start_write ( int iAddr , bit [31:0] bData , bit [3:0] bMask = '1 );
   @(posedge clk);
   ufp_itf.addr[0]   <= iAddr ;
   ufp_itf.rmask[0]  <= '0    ;
   ufp_itf.wmask[0]  <= bMask ;
   ufp_itf.wdata[0]  <= bData ;
   @(posedge clk);
   ufp_itf.addr[0]   <= 'x ;
   ufp_itf.rmask[0]  <= '0 ;
   ufp_itf.wmask[0]  <= 'x ;
   ufp_itf.wdata[0]  <= 'x ;

endtask

task read ( int iAddr );

   while( ufp_itf.resp[0] !== 1'H1 )
   begin
      @(posedge clk);
   end
   ufp_itf.addr[0]   <= iAddr ;
   ufp_itf.rmask[0]  <= '1 ;
   ufp_itf.wmask[0]  <= '0 ;
   ufp_itf.wdata[0]  <= 'x ;
   @(posedge clk);
   ufp_itf.addr[0]   <= 'x ;
   ufp_itf.rmask[0]  <= 'x ;
   ufp_itf.wmask[0]  <= '0 ;
   ufp_itf.wdata[0]  <= 'x ;

endtask

task write ( int iAddr , bit [31:0] bData , bit [3:0] bMask = '1 );

   while( ufp_itf.resp[0] !== 1'H1 )
   begin
      @(posedge clk);
   end
   ufp_itf.addr[0]   <= iAddr ;
   ufp_itf.rmask[0]  <= '0    ;
   ufp_itf.wmask[0]  <= bMask ;
   ufp_itf.wdata[0]  <= bData ;
   @(posedge clk);
   ufp_itf.addr[0]   <= 'x ;
   ufp_itf.rmask[0]  <= '0 ;
   ufp_itf.wmask[0]  <= 'x ;
   ufp_itf.wdata[0]  <= 'x ;

endtask

task idle (int iDelay = 0 );
   while( ufp_itf.resp[0] !== 1'H1 )
   begin
      @(negedge clk);
   end
   ufp_itf.addr[0]   <= 'x ;
   ufp_itf.rmask[0]  <= '0    ;
   ufp_itf.wmask[0]  <= '0 ;
   ufp_itf.wdata[0]  <= 'x ;
   repeat(iDelay)@(posedge clk);
endtask

task wait_for_resp ();

   bit bTimeOutEn ;
   bit bTimeOutError ;
   int iTimeOutCnt ;

   
   bTimeOutError = '0 ;
   bTimeOutEn = '1 ;
   iTimeOutCnt = '0 ;
   fork
   begin
      @( posedge ufp_itf.resp[0] );
   end
   begin
      while(bTimeOutEn)
      begin
         @(posedge clk);
         iTimeOutCnt++ ;
         if( iTimeOutCnt > 100 )
         begin
            bTimeOutError = '1 ;
            bTimeOutEn = '0 ;
            break ;
         end
      end
   end
   join_any

   bTimeOutEn = '0 ;
   if( bTimeOutError )
   begin
      $display("@%t [ERR] wait for resp time out!!!",$time());
   end

endtask

task tc_consecutive_read_write_hit ();

   top_tb.oRndUFP.randomize with {bRndAddr[31:16] == 16'H0000 ;};

   start_read( top_tb.oRndUFP.bRndAddr );

   read( {top_tb.oRndUFP.bRndAddr[31:5],5'H0}  ) ;
   read( {top_tb.oRndUFP.bRndAddr[31:5],5'H4}  ) ;
   read( {top_tb.oRndUFP.bRndAddr[31:5],5'H8}  ) ;

   write( {top_tb.oRndUFP.bRndAddr[31:5],5'H0} , $urandom(), 4'HF ) ;
   write( {top_tb.oRndUFP.bRndAddr[31:5],5'H4} , $urandom(), 4'HF ) ;
   write( {top_tb.oRndUFP.bRndAddr[31:5],5'H8} , $urandom(), 4'HF ) ;

   idle(10);

endtask

task tc_consecutive_read_write_clean_miss ();

   top_tb.oRndUFP.randomize with {
      bRndAddr[31:16] == 16'H0000 ;
      bRndAddr[15:9] == 5 ;
      bRndAddr[8:5] == 3 ;
      bRndAddr[4:2] == 0 ;
   };

   start_read( top_tb.oRndUFP.bRndAddr );

   idle(10);
   

   start_read( {top_tb.oRndUFP.bRndAddr[31:5],5'H0}  ) ;
   top_tb.oRndUFP.bRndAddr[31:9] = 23'D11 ;
   read( top_tb.oRndUFP.bRndAddr  ) ;
   top_tb.oRndUFP.bRndAddr[31:9] = 23'D5 ;
   read( {top_tb.oRndUFP.bRndAddr[31:5],5'H8}  ) ;

   idle(10);
   

   start_write( {top_tb.oRndUFP.bRndAddr[31:5],5'H0} , $urandom() ) ;
   top_tb.oRndUFP.bRndAddr[31:9] = 23'D12 ;
   write( top_tb.oRndUFP.bRndAddr, $urandom()  ) ;
   top_tb.oRndUFP.bRndAddr[31:9] = 23'D5 ;
   write( {top_tb.oRndUFP.bRndAddr[31:5],5'H8} , $urandom() ) ;

   idle(10);

endtask

task tc_consecutive_read_write_dirty_miss ();

   top_tb.oRndUFP.randomize with {
      bRndAddr[31:16] == 16'H0000 ;
      bRndAddr[15:9] == 5 ;
      bRndAddr[8:5] == 3 ;
      bRndAddr[4:2] == 0 ;
   };
   
   //fill all way at set 3

   top_tb.oRndUFP.bRndAddr[31:9] = 23'H0 ;
   start_read( top_tb.oRndUFP.bRndAddr );
   top_tb.oRndUFP.bRndAddr[31:9] = 23'H1 ;
   read( top_tb.oRndUFP.bRndAddr );
   top_tb.oRndUFP.bRndAddr[31:9] = 23'H2 ;
   read( top_tb.oRndUFP.bRndAddr );
   top_tb.oRndUFP.bRndAddr[31:9] = 23'H3 ;
   read( top_tb.oRndUFP.bRndAddr );

   idle(10);

   //make all way dirty
   top_tb.oRndUFP.bRndAddr[31:9] = 23'H0 ;
   start_write( top_tb.oRndUFP.bRndAddr , $urandom());
   top_tb.oRndUFP.bRndAddr[31:9] = 23'H1 ;
   write( top_tb.oRndUFP.bRndAddr , $urandom());
   top_tb.oRndUFP.bRndAddr[31:9] = 23'H2 ;
   write( top_tb.oRndUFP.bRndAddr , $urandom());
   top_tb.oRndUFP.bRndAddr[31:9] = 23'H3 ;
   write( top_tb.oRndUFP.bRndAddr , $urandom() );

   idle(10);

   //read with dirty miss
   top_tb.oRndUFP.bRndAddr[31:9] = 23'H5 ;
   start_read( top_tb.oRndUFP.bRndAddr );

   idle(10);

   //write with dirty miss
   top_tb.oRndUFP.bRndAddr[31:9] = 23'H6 ;
   start_write( top_tb.oRndUFP.bRndAddr ,$urandom());
   read( top_tb.oRndUFP.bRndAddr );

   idle(10);

endtask


endmodule
