-------------------------------------------------------------------------------
--
-- Copyright 2018 Ettus Research, a National Instruments Company
--
-- SPDX-License-Identifier: LGPL-3.0-or-later
--
--
-- Purpose:
--   The constants in this file are autogenerated by XmlParse and should
-- be used by testbench code to access specific register fields.
--
-------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

package PkgDaughterboardRegMap is

--===============================================================================
-- A numerically ordered list of registers and their VHDL source files
--===============================================================================

  -- AdcControl      : 0x600 (DaughterboardRegs.vhd)
  -- LmkStatus       : 0x604 (DaughterboardRegs.vhd)
  -- DbEnables       : 0x608 (DaughterboardRegs.vhd)
  -- DbChEnables     : 0x60C (DaughterboardRegs.vhd)
  -- TmonAlertStatus : 0x610 (DaughterboardRegs.vhd)
  -- VmonAlertStatus : 0x614 (DaughterboardRegs.vhd)
  -- SysrefControl   : 0x620 (DaughterboardRegs.vhd)
  -- DaughterboardId : 0x630 (DaughterboardRegs.vhd)

--===============================================================================
-- RegTypes
--===============================================================================

--===============================================================================
-- Register Group StaticControl
--===============================================================================

  -- AdcControl Register (from DaughterboardRegs.vhd)
  constant kAdcControl : integer := 16#600#; -- Register Offset
  constant kAdcControlSize: integer := 32;  -- register width in bits
  constant kAdcControlMask : std_logic_vector(31 downto 0) := X"00111111";
  constant kAdcAResetSetSize       : integer := 1;  --AdcControl:AdcAResetSet
  constant kAdcAResetSetMsb        : integer := 0;  --AdcControl:AdcAResetSet
  constant kAdcAResetSet           : integer := 0;  --AdcControl:AdcAResetSet
  constant kAdcAResetClearSize       : integer := 1;  --AdcControl:AdcAResetClear
  constant kAdcAResetClearMsb        : integer := 4;  --AdcControl:AdcAResetClear
  constant kAdcAResetClear           : integer := 4;  --AdcControl:AdcAResetClear
  constant kAdcBResetSetSize       : integer := 1;  --AdcControl:AdcBResetSet
  constant kAdcBResetSetMsb        : integer := 8;  --AdcControl:AdcBResetSet
  constant kAdcBResetSet           : integer := 8;  --AdcControl:AdcBResetSet
  constant kAdcBResetClearSize       : integer :=  1;  --AdcControl:AdcBResetClear
  constant kAdcBResetClearMsb        : integer := 12;  --AdcControl:AdcBResetClear
  constant kAdcBResetClear           : integer := 12;  --AdcControl:AdcBResetClear
  constant kAdcSpiEnSetSize       : integer :=  1;  --AdcControl:AdcSpiEnSet
  constant kAdcSpiEnSetMsb        : integer := 16;  --AdcControl:AdcSpiEnSet
  constant kAdcSpiEnSet           : integer := 16;  --AdcControl:AdcSpiEnSet
  constant kAdcSpiEnClearSize       : integer :=  1;  --AdcControl:AdcSpiEnClear
  constant kAdcSpiEnClearMsb        : integer := 20;  --AdcControl:AdcSpiEnClear
  constant kAdcSpiEnClear           : integer := 20;  --AdcControl:AdcSpiEnClear

  -- LmkStatus Register (from DaughterboardRegs.vhd)
  constant kLmkStatus : integer := 16#604#; -- Register Offset
  constant kLmkStatusSize: integer := 32;  -- register width in bits
  constant kLmkStatusMask : std_logic_vector(31 downto 0) := X"00000013";
  constant kLmkLockedSize       : integer := 1;  --LmkStatus:LmkLocked
  constant kLmkLockedMsb        : integer := 0;  --LmkStatus:LmkLocked
  constant kLmkLocked           : integer := 0;  --LmkStatus:LmkLocked
  constant kLmkUnlockedStickySize       : integer := 1;  --LmkStatus:LmkUnlockedSticky
  constant kLmkUnlockedStickyMsb        : integer := 1;  --LmkStatus:LmkUnlockedSticky
  constant kLmkUnlockedSticky           : integer := 1;  --LmkStatus:LmkUnlockedSticky
  constant kLmkUnlockedStickyResetSize       : integer := 1;  --LmkStatus:LmkUnlockedStickyReset
  constant kLmkUnlockedStickyResetMsb        : integer := 4;  --LmkStatus:LmkUnlockedStickyReset
  constant kLmkUnlockedStickyReset           : integer := 4;  --LmkStatus:LmkUnlockedStickyReset

  -- DbEnables Register (from DaughterboardRegs.vhd)
  constant kDbEnables : integer := 16#608#; -- Register Offset
  constant kDbEnablesSize: integer := 32;  -- register width in bits
  constant kDbEnablesMask : std_logic_vector(31 downto 0) := X"11111111";
  constant kDbPwrEnableSetSize       : integer := 1;  --DbEnables:DbPwrEnableSet
  constant kDbPwrEnableSetMsb        : integer := 0;  --DbEnables:DbPwrEnableSet
  constant kDbPwrEnableSet           : integer := 0;  --DbEnables:DbPwrEnableSet
  constant kDbPwrEnableClearSize       : integer := 1;  --DbEnables:DbPwrEnableClear
  constant kDbPwrEnableClearMsb        : integer := 4;  --DbEnables:DbPwrEnableClear
  constant kDbPwrEnableClear           : integer := 4;  --DbEnables:DbPwrEnableClear
  constant kLnaCtrlEnableSetSize       : integer := 1;  --DbEnables:LnaCtrlEnableSet
  constant kLnaCtrlEnableSetMsb        : integer := 8;  --DbEnables:LnaCtrlEnableSet
  constant kLnaCtrlEnableSet           : integer := 8;  --DbEnables:LnaCtrlEnableSet
  constant kLnaCtrlEnableClearSize       : integer :=  1;  --DbEnables:LnaCtrlEnableClear
  constant kLnaCtrlEnableClearMsb        : integer := 12;  --DbEnables:LnaCtrlEnableClear
  constant kLnaCtrlEnableClear           : integer := 12;  --DbEnables:LnaCtrlEnableClear
  constant kLmkSpiEnableSetSize       : integer :=  1;  --DbEnables:LmkSpiEnableSet
  constant kLmkSpiEnableSetMsb        : integer := 16;  --DbEnables:LmkSpiEnableSet
  constant kLmkSpiEnableSet           : integer := 16;  --DbEnables:LmkSpiEnableSet
  constant kLmkSpiEnableClearSize       : integer :=  1;  --DbEnables:LmkSpiEnableClear
  constant kLmkSpiEnableClearMsb        : integer := 20;  --DbEnables:LmkSpiEnableClear
  constant kLmkSpiEnableClear           : integer := 20;  --DbEnables:LmkSpiEnableClear
  constant kDbCtrlEnableSetSize       : integer :=  1;  --DbEnables:DbCtrlEnableSet
  constant kDbCtrlEnableSetMsb        : integer := 24;  --DbEnables:DbCtrlEnableSet
  constant kDbCtrlEnableSet           : integer := 24;  --DbEnables:DbCtrlEnableSet
  constant kDbCtrlEnableClearSize       : integer :=  1;  --DbEnables:DbCtrlEnableClear
  constant kDbCtrlEnableClearMsb        : integer := 28;  --DbEnables:DbCtrlEnableClear
  constant kDbCtrlEnableClear           : integer := 28;  --DbEnables:DbCtrlEnableClear

  -- DbChEnables Register (from DaughterboardRegs.vhd)
  constant kDbChEnables : integer := 16#60C#; -- Register Offset
  constant kDbChEnablesSize: integer := 32;  -- register width in bits
  constant kDbChEnablesMask : std_logic_vector(31 downto 0) := X"000000ff";
  constant kCh0EnableSize       : integer := 1;  --DbChEnables:Ch0Enable
  constant kCh0EnableMsb        : integer := 0;  --DbChEnables:Ch0Enable
  constant kCh0Enable           : integer := 0;  --DbChEnables:Ch0Enable
  constant kCh1EnableSize       : integer := 1;  --DbChEnables:Ch1Enable
  constant kCh1EnableMsb        : integer := 1;  --DbChEnables:Ch1Enable
  constant kCh1Enable           : integer := 1;  --DbChEnables:Ch1Enable
  constant kCh2EnableSize       : integer := 1;  --DbChEnables:Ch2Enable
  constant kCh2EnableMsb        : integer := 2;  --DbChEnables:Ch2Enable
  constant kCh2Enable           : integer := 2;  --DbChEnables:Ch2Enable
  constant kCh3EnableSize       : integer := 1;  --DbChEnables:Ch3Enable
  constant kCh3EnableMsb        : integer := 3;  --DbChEnables:Ch3Enable
  constant kCh3Enable           : integer := 3;  --DbChEnables:Ch3Enable
  constant kCh4EnableSize       : integer := 1;  --DbChEnables:Ch4Enable
  constant kCh4EnableMsb        : integer := 4;  --DbChEnables:Ch4Enable
  constant kCh4Enable           : integer := 4;  --DbChEnables:Ch4Enable
  constant kCh5EnableSize       : integer := 1;  --DbChEnables:Ch5Enable
  constant kCh5EnableMsb        : integer := 5;  --DbChEnables:Ch5Enable
  constant kCh5Enable           : integer := 5;  --DbChEnables:Ch5Enable
  constant kCh6EnableSize       : integer := 1;  --DbChEnables:Ch6Enable
  constant kCh6EnableMsb        : integer := 6;  --DbChEnables:Ch6Enable
  constant kCh6Enable           : integer := 6;  --DbChEnables:Ch6Enable
  constant kCh7EnableSize       : integer := 1;  --DbChEnables:Ch7Enable
  constant kCh7EnableMsb        : integer := 7;  --DbChEnables:Ch7Enable
  constant kCh7Enable           : integer := 7;  --DbChEnables:Ch7Enable

  -- TmonAlertStatus Register (from DaughterboardRegs.vhd)
  constant kTmonAlertStatus : integer := 16#610#; -- Register Offset
  constant kTmonAlertStatusSize: integer := 32;  -- register width in bits
  constant kTmonAlertStatusMask : std_logic_vector(31 downto 0) := X"00000013";
  constant kTmonAlertSize       : integer := 1;  --TmonAlertStatus:TmonAlert
  constant kTmonAlertMsb        : integer := 0;  --TmonAlertStatus:TmonAlert
  constant kTmonAlert           : integer := 0;  --TmonAlertStatus:TmonAlert
  constant kTmonAlertStickySize       : integer := 1;  --TmonAlertStatus:TmonAlertSticky
  constant kTmonAlertStickyMsb        : integer := 1;  --TmonAlertStatus:TmonAlertSticky
  constant kTmonAlertSticky           : integer := 1;  --TmonAlertStatus:TmonAlertSticky
  constant kTmonAlertStickyResetSize       : integer := 1;  --TmonAlertStatus:TmonAlertStickyReset
  constant kTmonAlertStickyResetMsb        : integer := 4;  --TmonAlertStatus:TmonAlertStickyReset
  constant kTmonAlertStickyReset           : integer := 4;  --TmonAlertStatus:TmonAlertStickyReset

  -- VmonAlertStatus Register (from DaughterboardRegs.vhd)
  constant kVmonAlertStatus : integer := 16#614#; -- Register Offset
  constant kVmonAlertStatusSize: integer := 32;  -- register width in bits
  constant kVmonAlertStatusMask : std_logic_vector(31 downto 0) := X"00000013";
  constant kVmonAlertSize       : integer := 1;  --VmonAlertStatus:VmonAlert
  constant kVmonAlertMsb        : integer := 0;  --VmonAlertStatus:VmonAlert
  constant kVmonAlert           : integer := 0;  --VmonAlertStatus:VmonAlert
  constant kVmonAlertStickySize       : integer := 1;  --VmonAlertStatus:VmonAlertSticky
  constant kVmonAlertStickyMsb        : integer := 1;  --VmonAlertStatus:VmonAlertSticky
  constant kVmonAlertSticky           : integer := 1;  --VmonAlertStatus:VmonAlertSticky
  constant kVmonAlertStickyResetSize       : integer := 1;  --VmonAlertStatus:VmonAlertStickyReset
  constant kVmonAlertStickyResetMsb        : integer := 4;  --VmonAlertStatus:VmonAlertStickyReset
  constant kVmonAlertStickyReset           : integer := 4;  --VmonAlertStatus:VmonAlertStickyReset

  -- SysrefControl Register (from DaughterboardRegs.vhd)
  constant kSysrefControl : integer := 16#620#; -- Register Offset
  constant kSysrefControlSize: integer := 32;  -- register width in bits
  constant kSysrefControlMask : std_logic_vector(31 downto 0) := X"00000001";
  constant kSysrefGoSize       : integer := 1;  --SysrefControl:SysrefGo
  constant kSysrefGoMsb        : integer := 0;  --SysrefControl:SysrefGo
  constant kSysrefGo           : integer := 0;  --SysrefControl:SysrefGo

  -- DaughterboardId Register (from DaughterboardRegs.vhd)
  constant kDaughterboardId : integer := 16#630#; -- Register Offset
  constant kDaughterboardIdSize: integer := 32;  -- register width in bits
  constant kDaughterboardIdMask : std_logic_vector(31 downto 0) := X"0001ffff";
  constant kDbIdValSize       : integer := 16;  --DaughterboardId:DbIdVal
  constant kDbIdValMsb        : integer := 15;  --DaughterboardId:DbIdVal
  constant kDbIdVal           : integer :=  0;  --DaughterboardId:DbIdVal
  constant kSlotIdValSize       : integer :=  1;  --DaughterboardId:SlotIdVal
  constant kSlotIdValMsb        : integer := 16;  --DaughterboardId:SlotIdVal
  constant kSlotIdVal           : integer := 16;  --DaughterboardId:SlotIdVal

end package;

package body PkgDaughterboardRegMap is

  -- function kAdcControlRec not implemented because PkgXReg in this project does not support XReg2_t.

  -- function kLmkStatusRec not implemented because PkgXReg in this project does not support XReg2_t.

  -- function kDbEnablesRec not implemented because PkgXReg in this project does not support XReg2_t.

  -- function kDbChEnablesRec not implemented because PkgXReg in this project does not support XReg2_t.

  -- function kTmonAlertStatusRec not implemented because PkgXReg in this project does not support XReg2_t.

  -- function kVmonAlertStatusRec not implemented because PkgXReg in this project does not support XReg2_t.

  -- function kSysrefControlRec not implemented because PkgXReg in this project does not support XReg2_t.

  -- function kDaughterboardIdRec not implemented because PkgXReg in this project does not support XReg2_t.

end package body;