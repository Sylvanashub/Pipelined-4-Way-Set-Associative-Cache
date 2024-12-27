
class rand_ufp ;

   rand bit [31:0]   bRndAddr ;
   rand bit          bRndRw   ;
   rand bit [3:0]    bRndRmask ;
   rand bit [3:0]    bRndWmask ;
   rand bit [31:0]   bRndWdata ;

   constraint cstRndAddr {
      bRndAddr[1:0] == 2'H0 ;
      bRndWmask != 4'H0 ;
   }



endclass
