module top_tb;


    //---------------------------------------------------------------------------------
    // Waveform generation.
    //---------------------------------------------------------------------------------
    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, "+all");

         $vcdplusfile("test.vpd");
        $vcdpluson(0);
        $vcdplusmemon(dut);
    end

    //---------------------------------------------------------------------------------
    // TODO: Declare cache port signals:
    //---------------------------------------------------------------------------------
    bit clk;
    bit rst;
    reg [31:0] ufp_addr ;
   bit [255:0] dfp_rdata ;
    mem_itf_w_mask #(.CHANNELS(1))                 ufp_itf(.*);
    mem_itf_wo_mask #(.CHANNELS(1), .DWIDTH(256))  dfp_itf(.*);
   simple_memory_256_wo_mask mem ( .itf( dfp_itf ) ) ;
   ufp_mst  ufp_mst ();
    //---------------------------------------------------------------------------------
    // TODO: Generate a clock:
    //---------------------------------------------------------------------------------
   
    always #1ns clk = ~clk;


    //---------------------------------------------------------------------------------
    // TODO: Write a task to generate reset:
    //---------------------------------------------------------------------------------
    initial begin
        rst = 1'b1;
        repeat (2) @(posedge clk);
        rst <= 1'b0;
    end

    //---------------------------------------------------------------------------------
    // TODO: Instantiate the DUT and physical memory:
    //---------------------------------------------------------------------------------
    cache dut(
        .clk            (clk),
        .rst            (rst),

        .ufp_addr      (ufp_itf.addr [0]),
        //.ufp_addr      (ufp_addr),
        .ufp_rmask     (ufp_itf.rmask[0]),
        .ufp_wmask     (ufp_itf.wmask[0]),
        .ufp_rdata     (ufp_itf.rdata[0]),
        .ufp_wdata     (ufp_itf.wdata[0]),
        .ufp_resp      (ufp_itf.resp [0]),

        .dfp_addr      (dfp_itf.addr [0]),
        .dfp_read      (dfp_itf.read [0]),
        .dfp_write     (dfp_itf.write[0]),
        .dfp_rdata     (dfp_itf.rdata[0]),
        //.dfp_rdata     ( dfp_rdata ),
        .dfp_wdata     (dfp_itf.wdata[0]),
        .dfp_resp      (dfp_itf.resp [0])

    );

    cache_rm rm (
        .clk            (clk),
        .rst            (rst),

        .ufp_addr      (ufp_itf.addr [0]),
        .ufp_rmask     (ufp_itf.rmask[0]),
        .ufp_wmask     (ufp_itf.wmask[0]),
        .ufp_rdata     (ufp_itf.rdata[0]),
        .ufp_wdata     (ufp_itf.wdata[0]),
        .ufp_resp      (ufp_itf.resp [0]),

        .dfp_addr      (dfp_itf.addr [0]),
        .dfp_read      (dfp_itf.read [0]),
        .dfp_write     (dfp_itf.write[0]),
        .dfp_rdata     (dfp_itf.rdata[0]),
        .dfp_wdata     (dfp_itf.wdata[0]),
        .dfp_resp      (dfp_itf.resp [0])

    );

    //---------------------------------------------------------------------------------
    // TODO: Write tasks to test various functionalities:
    //---------------------------------------------------------------------------------
   
   always@(posedge clk)
   begin
      if( rst )
         dfp_rdata <= {8{$urandom()}} ;
      else if( dfp_itf.resp[0] )
         dfp_rdata <= {8{$urandom()}} ;
   end

   task info ( string strMsg ) ;
   $display("@%t [INF] %s",$time ,strMsg ) ;
   endtask

   task error ( string strMsg ) ;
   $display("@%t [ERR] %s",$time ,strMsg ) ;
   endtask

   task ufp_init() ;
      ufp_itf.addr[0]  = '0 ;
      ufp_itf.rmask[0] = '0 ;
      ufp_itf.wmask[0] = '0 ;
      ufp_itf.wdata[0] = '0 ;
   endtask

   task mem_init () ;


   endtask

   task ufp_read ( int iAddr ) ;
      
      @(posedge clk) ;
      ufp_itf.addr[0] = iAddr ;
      ufp_itf.rmask[0] = '1 ;
      ufp_itf.wmask[0] = '0 ;
      ufp_itf.wdata[0] = '0 ;


      @(posedge clk) ;
      ufp_itf.rmask[0] = '0 ;
      while( !ufp_itf.resp[0] )
      begin
         @(posedge clk) ;
      end
      info($sformatf("UFP Read [0x%x] = 0x%x",iAddr,ufp_itf.rdata[0]));

   endtask

   task ufp_pipeline_read ( int iAddr , bit bWaitForResp = '1 ) ;

      fork
      begin
         @(posedge clk) ;
         ufp_itf.addr[0]   <= iAddr ;
         ufp_itf.rmask[0]  <= '1 ;
         ufp_itf.wmask[0]  <= '0 ;
         ufp_itf.wdata[0]  <= '0 ;
      end
      begin
         if( bWaitForResp )
         begin
            @(negedge clk) ;
            while( !ufp_itf.resp[0] )
            begin
               @(negedge clk) ;
            end
         end
      end
      join

   endtask

   task ufp_pipeline_write ( int iAddr , bit [31:0] bData , bit [3:0] bMask = '1 , bit bWaitForResp = '1 ) ;

      fork
      begin
         @(posedge clk) ;
         ufp_addr <= iAddr ;
         ufp_itf.addr[0]   <= iAddr ;
         ufp_itf.rmask[0]  <= '0 ;
         ufp_itf.wmask[0]  <= bMask ;
         ufp_itf.wdata[0]  <= bData ;
      end
      begin
      if( bWaitForResp )
      begin
         @(negedge clk) ;
         while( !ufp_itf.resp[0] )
         begin
            @(negedge clk) ;
         end
      end
      end
      join

   endtask

   task ufp_pipeline_idle ( int iWait = 0 ) ;

      fork
      begin
         @(posedge clk) ;
         ufp_addr <= 'x ;
         ufp_itf.addr[0]   <= 'x ;
         ufp_itf.rmask[0]  <= 'x ;
         ufp_itf.wmask[0]  <= 'x ;
         ufp_itf.wdata[0]  <= 'x ;
      end
      begin
         @(negedge clk) ;
         while( !ufp_itf.resp[0] )
         begin
            @(negedge clk) ;
         end
         ufp_itf.wmask[0] <= '0 ;
         ufp_itf.rmask[0] <= '0 ;
      end
      join

      repeat(iWait)
      begin
         @(negedge clk);
      end

   endtask

   rand_ufp oRndUFP = new() ;

   task ufp_random_read ( int iAddr , int iLen ) ;
      
      @(posedge clk) ;
      ufp_itf.addr[0] <= iAddr ;
      ufp_itf.rmask[0]<= '1 ;
      ufp_itf.wmask[0]<= '0 ;
      ufp_itf.wdata[0]<= '0 ;


      for(int i=1;i<iLen;i++)
      begin
         @(posedge clk) ;
         //ufp_itf.addr[0] <= iAddr + i*4 ;
         oRndUFP.randomize with {
            //bRndAddr < 4096*4*4 ;
            bRndAddr[31:18] == 14'H0000 ;
            bRndAddr[1:0] == 2'H0 ;
         };
         ufp_itf.addr[0] <= oRndUFP.bRndAddr ;
         do
         begin
            @(negedge clk) ;
         end
         while( !ufp_itf.resp[0] ) ;

         //info($sformatf("UFP Random Read [0x%x] = 0x%x",iAddr+i*4,ufp_itf.rdata[0]));
         info($sformatf("UFP Random Read [0x%x] = 0x%x",oRndUFP.bRndAddr,ufp_itf.rdata[0]));

      end
      ufp_itf.rmask[0]<= '0 ;


   endtask

   task tc_hit ();

      //fill cache
      oRndUFP.randomize with {bRndAddr[31:16] == '0;bRndAddr[8:5] == 4'HA ; bRndAddr[15:9] == 7'H12 ; };
      ufp_pipeline_read( oRndUFP.bRndAddr , 1'H0 ) ;
      for(int i=1;i<4;i++)
      begin
         oRndUFP.bRndAddr[15:9] = oRndUFP.bRndAddr[15:9] + 7'H01;
         ufp_pipeline_read( oRndUFP.bRndAddr ) ;
      end

      
      
      repeat(2**8)
      begin
      //read hit
      oRndUFP.randomize with {bRndAddr[31:16] == '0;bRndAddr[8:5] == 4'HA ; bRndAddr[15:9] inside {[7'H12:7'H15]} ; };
      if( oRndUFP.bRndRw )
      ufp_pipeline_read( oRndUFP.bRndAddr ) ;
      else
      ufp_pipeline_write( oRndUFP.bRndAddr , $urandom() , oRndUFP.bRndWmask) ;

      end

      ufp_pipeline_idle() ;

   endtask


   task tc_clean_miss ();

      //fill cache
      oRndUFP.randomize with {bRndAddr[31:16] == '0;bRndAddr[8:5] == 4'H5 ;};
      ufp_pipeline_read( oRndUFP.bRndAddr , 1'H0 ) ;
      for(int i=1;i<4;i++)
      begin
         oRndUFP.bRndAddr[15:9] = oRndUFP.bRndAddr[15:9] + 7'H01;
         ufp_pipeline_read( oRndUFP.bRndAddr ) ;
      end
      
      repeat(2**16)
      begin
      //read miss
      oRndUFP.bRndAddr[15:9] = oRndUFP.bRndAddr[15:9] + 7'H01;
      ufp_pipeline_read( oRndUFP.bRndAddr ) ;

      //write miss
      oRndUFP.bRndAddr[15:9] = oRndUFP.bRndAddr[15:9] + 7'H01;
      ufp_pipeline_write( oRndUFP.bRndAddr , $urandom() , oRndUFP.bRndWmask ) ;
      end

      ufp_pipeline_idle() ;

   endtask

   task tc_dirty_miss ();

      bit [3:0]   bSetIdx ;

      bSetIdx = 4'H6 ;

      //fill cache
      oRndUFP.randomize with {bRndAddr[31:16] == '0;bRndAddr[8:5] == bSetIdx ; bRndAddr[15:9] == 7'H33 ; };
      ufp_pipeline_read( oRndUFP.bRndAddr , 1'H0 ) ;
      for(int i=1;i<4;i++)
      begin
         oRndUFP.bRndAddr[15:9] = oRndUFP.bRndAddr[15:9] + 7'H01;
         ufp_pipeline_read( oRndUFP.bRndAddr ) ;
      end

      //make dirty
      repeat(16)
      begin
         oRndUFP.randomize with {bRndAddr[31:16] == '0;bRndAddr[8:5] == bSetIdx ; bRndAddr[15:9] inside {[7'H33:7'H36]} ; };
         ufp_pipeline_write( oRndUFP.bRndAddr , $urandom()) ;
      end

      
      repeat(2**10)
      begin

         oRndUFP.randomize with {bRndAddr[31:16] == '0;bRndAddr[8:5] == bSetIdx ; !(bRndAddr[15:9] inside {[7'H33:7'H36]}) ; };
         if(oRndUFP.bRndRw )
         begin
            //read dirty miss
            ufp_pipeline_read( oRndUFP.bRndAddr ) ;
         end
         else
         begin
            //write miss
            ufp_pipeline_write( oRndUFP.bRndAddr , $urandom()) ;
         end

      end

      ufp_pipeline_idle() ;

   endtask


   task tc_single_write ();

      //fill cache
      oRndUFP.randomize with {bRndAddr[31:16] == '0;};
      ufp_pipeline_write( oRndUFP.bRndAddr , $urandom() , 4'HF , 1'H0 ) ;

      repeat(16)
      begin
         oRndUFP.randomize with {bRndAddr[31:16] == '0;};
         ufp_pipeline_write( oRndUFP.bRndAddr , $urandom() ) ;
      end

      ufp_pipeline_idle() ;

   endtask

    //---------------------------------------------------------------------------------
    // TODO: Main initial block that calls your tasks, then calls $finish
    //---------------------------------------------------------------------------------
   initial
   begin
      //mem_init() ;
      ufp_init() ;
      @(negedge rst);
   
      //repeat(10) @(posedge clk) ;

      //ufp_random_read( 0 , 16384*4 ) ;
      //ufp_random_read( 0 , 16384 ) ;

      if(0)
      begin
      ufp_pipeline_read( 0 , 1'H0 ) ;
      ufp_pipeline_read( 4 ) ;
      ufp_pipeline_write( 4 , $urandom()) ;
      ufp_pipeline_read( 4 ) ;
      ufp_pipeline_idle() ;
      end

      if(1)
      begin
      ufp_pipeline_read( 0 , 1'H0 ) ;
      repeat(2**18)
      begin

         oRndUFP.randomize with {
            bRndAddr[31:16] == 16'H0000 ;
            bRndAddr[8:5] inside {0,3,7,12,15} ;
            bRndAddr[4:2] inside {0,3,6,7} ;
         };
         
         if( oRndUFP.bRndRw )
         begin
            ufp_pipeline_read( oRndUFP.bRndAddr ) ;
            ufp_pipeline_idle($urandom()%10) ;
         end
         else
         begin
            ufp_pipeline_write( oRndUFP.bRndAddr , $urandom(), oRndUFP.bRndWmask ) ;
            ufp_pipeline_idle($urandom()%10) ;
         end
         
      end
      //ufp_pipeline_idle() ;

      end

      //tc_hit();
      if(0)
      begin
         oRndUFP.randomize ;
         ufp_pipeline_write( oRndUFP.bRndAddr , $urandom(), oRndUFP.bRndWmask , 1'H0) ;
         ufp_pipeline_write( oRndUFP.bRndAddr , $urandom(), oRndUFP.bRndWmask ) ;
         oRndUFP.randomize ;
         ufp_pipeline_write( oRndUFP.bRndAddr , $urandom(), oRndUFP.bRndWmask ) ;
         ufp_pipeline_write( oRndUFP.bRndAddr , $urandom(), oRndUFP.bRndWmask ) ;
         repeat(5)
         begin
         oRndUFP.randomize with { bRndAddr[8:5] == 4'H3 ;} ;
         ufp_pipeline_write( oRndUFP.bRndAddr , $urandom(), oRndUFP.bRndWmask ) ;
         end
         ufp_pipeline_idle() ;
      end

      //tc_clean_miss();
      //tc_dirty_miss();
      //tc_single_write();
      //info($sformatf("mem size = %d",mem.internal_memory_array.size()));
      if(0)
      begin
         oRndUFP.randomize with {bRndAddr[31:16] == 16'H0000 ;};
         ufp_pipeline_read( oRndUFP.bRndAddr , 1'H0) ;
         ufp_pipeline_write( oRndUFP.bRndAddr , $urandom(), 4'HF) ;
         ufp_pipeline_read( oRndUFP.bRndAddr) ;
         ufp_pipeline_idle() ;
      end


      if(0)
      begin
         oRndUFP.randomize with {bRndAddr[31:16] == 16'H0000 ;};

         ufp_mst.start_read( oRndUFP.bRndAddr ) ;

         repeat(2**16)
         begin

            oRndUFP.randomize with {
               bRndAddr[31:16] == 16'H0000 ;
               bRndAddr[15:9] inside {[0:15]} ;
               bRndAddr[8:5] inside {0,3,7,12,15} ;
               bRndAddr[4:2] inside {0,3,6,7} ;
            };
            

            if( oRndUFP.bRndRw )

               ufp_mst.read( oRndUFP.bRndAddr ) ;

            else

               ufp_mst.write( oRndUFP.bRndAddr , $urandom(), oRndUFP.bRndWmask) ;


         end

         ufp_mst.idle();
      end

      if(0)
      begin
      ufp_mst.tc_consecutive_read_write_hit();
      ufp_mst.tc_consecutive_read_write_clean_miss();
      ufp_mst.tc_consecutive_read_write_dirty_miss();
      end

      repeat(10) @(posedge clk) ;

      $finish();
   end


endmodule : top_tb
