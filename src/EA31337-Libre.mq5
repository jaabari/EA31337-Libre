//+------------------------------------------------------------------+
//|                              EA31337 Libre - Forex trading robot |
//|                                 Copyright 2016-2021, EA31337 Ltd |
//|                                       https://github.com/EA31337 |
//+------------------------------------------------------------------+

/*
 *  This file is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.

 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.

 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

// Includes.
#include "include/includes.h"

// EA properties.
#ifdef __MQL4__
#property copyright ea_copy
#property description ea_name
#property description ea_desc
#property link ea_link
#property version ea_version
#endif

// Global variables.
EA *ea;

/* EA event handler functions */

/**
 * Initialization function of the expert.
 */
int OnInit() {
  bool _initiated = true;
  PrintFormat("%s v%s (%s) initializing...", ea_name, ea_version, ea_link);
  _initiated &= InitEA();
  _initiated &= InitStrategies();
  if (GetLastError() > 0) {
    ea.GetLogger().Error("Error during initializing!", __FUNCTION_LINE__, Terminal::GetLastErrorText());
  }
  if (EA_DisplayDetailsOnChart) {
    DisplayStartupInfo(true);
  }
  ea.GetLogger().Flush();
  Chart::WindowRedraw();
  if (!_initiated) {
    ea.GetState().Enable(false);
  }
  return (_initiated ? INIT_SUCCEEDED : INIT_FAILED);
}

/**
 * Deinitialization function of the expert.
 */
void OnDeinit(const int reason) { DeinitVars(); }

/**
 * "Tick" event handler function (EA only).
 *
 * Invoked when a new tick for a symbol is received, to the chart of which the Expert Advisor is attached.
 */
void OnTick() {
  EAProcessResult _result = ea.ProcessTick();
  if (_result.stg_processed || ea.GetState().new_periods > 0) {
    if (EA_DisplayDetailsOnChart && (Terminal::IsVisualMode() || Terminal::IsRealtime())) {
      string _text = StringFormat("%s v%s by %s (%s)\n", ea_name, ea_version, ea_author, ea_link);
      _text += SerializerConverter::FromObject(ea, SERIALIZER_FLAG_INCLUDE_DYNAMIC).ToString<SerializerJson>();
      Comment(_text);
    }
    if (ea.GetState().new_periods > 0) {
      ea.GetLogger().Flush(10);
    }
  }
}

#ifdef __MQL5__
/**
 * "Trade" event handler function (MQL5 only).
 *
 * Invoked when a trade operation is completed on a trade server.
 */
void OnTrade() {}

/**
 * "OnTradeTransaction" event handler function (MQL5 only).
 *
 * Invoked when performing some definite actions on a trade account, its state changes.
 */
void OnTradeTransaction(const MqlTradeTransaction &trans,  // Trade transaction structure.
                        const MqlTradeRequest &request,    // Request structure.
                        const MqlTradeResult &result       // Result structure.
) {}
#endif

/**
 * "Timer" event handler function.
 *
 * Invoked periodically generated by the EA that has activated the timer by the EventSetTimer function.
 * Usually, this function is called by OnInit.
 */
void OnTimer() {}

/**
 * "TesterInit" event handler function.
 *
 * The start of optimization in the strategy tester before the first optimization pass.
 */
void TesterInit() {}

/**
 * "OnTester" event handler function.
 *
 * Invoked after a history testing of an Expert Advisor on the chosen interval is over.
 * It is called right before the call of OnDeinit().
 */
double OnTester() { return 1.0; }

/**
 * "OnTesterPass" event handler function.
 *
 * Invoked when a frame is received during Expert Advisor optimization in the strategy tester.
 */
void OnTesterPass() {}

/**
 * "OnTesterDeinit" event handler function.
 *
 * Invoked after the end of Expert Advisor optimization in the strategy tester.
 */
void OnTesterDeinit() {}

/**
 * "OnBookEvent" event handler function.
 *
 * Invoked on Depth of Market changes.
 * To pre-subscribe use the MarketBookAdd() function.
 * In order to unsubscribe for a particular symbol, call MarketBookRelease().
 */
void OnBookEvent(const string &symbol) {}

/**
 * "OnBookEvent" event handler function.
 *
 * Invoked by the client terminal when a user is working with a chart.
 */
void OnChartEvent(const int id,          // Event ID.
                  const long &lparam,    // Parameter of type long event.
                  const double &dparam,  // Parameter of type double event.
                  const string &sparam   // Parameter of type string events.
) {}

/* Custom EA functions */

/**
 * Display startup info.
 */
bool DisplayStartupInfo(bool _startup = false, string sep = "\n") {
  string _output = "";
  ResetLastError();
  if (ea.GetState().IsOptimizationMode() || (ea.GetState().IsTestingMode() && !ea.GetState().IsVisualMode())) {
    // Ignore chart updates when optimizing or testing in non-visual mode.
    return false;
  }
  _output += "TERMINAL: " + ea.GetTerminal().ToString() + sep;
  _output += "ACCOUNT: " + ea.Account().ToString() + sep;
  _output += "EA: " + ea.ToString() + sep;
  _output += "SYMBOL: " + ea.SymbolInfo().ToString() + sep;
  _output += "MARKET: " + ea.Market().ToString() + sep;
  if (_startup) {
    if (ea.GetState().IsTradeAllowed()) {
      if (!Terminal::HasError()) {
        _output += sep + "Trading is allowed, waiting for new bars...";
      } else {
        _output += sep + "Trading is allowed, but there is some issue...";
        _output += sep + Terminal::GetLastErrorText();
        ea.GetLogger().AddLastError(__FUNCTION_LINE__);
      }
    } else if (Terminal::IsRealtime()) {
      _output += sep + StringFormat(
                           "Error %d: Trading is not allowed for this symbol, please enable automated trading or check "
                           "the settings!",
                           __LINE__);
    } else {
      _output += sep + "Waiting for new bars...";
    }
  }
  Comment(_output);
  return !Terminal::HasError();
}

/**
 * Init EA.
 */
bool InitEA() {
  bool _initiated = true;
  EAParams ea_params(__FILE__, VerboseLevel);
  // ea_params.SetChartInfoFreq(EA_DisplayDetailsOnChart ? 2 : 0);
  // EA params.
  ea_params.SetDetails(ea_name, ea_desc, ea_version, StringFormat("%s (%s)", ea_author, ea_link));
  // Risk params.
  ea_params.Set(STRUCT_ENUM(EAParams, EA_PARAM_PROP_RISK_MARGIN_MAX), EA_Risk_MarginMax);
  // Init instance.
  ea = new EA(ea_params);
  if (!ea.GetState().IsTradeAllowed()) {
    ea.GetLogger().Error(
        "Trading is not allowed for this symbol, please enable automated trading or check the settings!",
        __FUNCTION_LINE__);
    _initiated = false;
  }
  return _initiated;
}

/**
 * Init strategies.
 */
bool InitStrategies() {
  bool _res = true;
  int _magic_step = FINAL_ENUM_TIMEFRAMES_INDEX;
  long _magic_no = EA_MagicNumber;
  ResetLastError();
  _res &= EAStrategyAdd(EA_Strategy, EA_Strategy_Active_Tf);
  _res &= GetLastError() == 0 || GetLastError() == 5053;  // @fixme: error 5053?
  ResetLastError();
  return _res;
}

/**
 * Adds strategy to the given timeframe.
 */
bool EAStrategyAdd(ENUM_STRATEGY _stg, int _tfs) {
  unsigned int _magic_no = EA_MagicNumber + _stg * FINAL_ENUM_TIMEFRAMES_INDEX;
  switch (_stg) {
    case STRAT_AC:
      return ea.StrategyAdd<Stg_AC>(_tfs, _magic_no, _stg);
    case STRAT_AD:
      return ea.StrategyAdd<Stg_AD>(_tfs, _magic_no, _stg);
    case STRAT_ADX:
      return ea.StrategyAdd<Stg_ADX>(_tfs, _magic_no, _stg);
    case STRAT_AMA:
      return ea.StrategyAdd<Stg_AMA>(_tfs, _magic_no, _stg);
    case STRAT_ASI:
      return ea.StrategyAdd<Stg_ASI>(_tfs, _magic_no, _stg);
    case STRAT_ATR:
      return ea.StrategyAdd<Stg_ATR>(_tfs, _magic_no, _stg);
    case STRAT_ALLIGATOR:
      return ea.StrategyAdd<Stg_Alligator>(_tfs, _magic_no, _stg);
    case STRAT_AWESOME:
      return ea.StrategyAdd<Stg_Awesome>(_tfs, _magic_no, _stg);
    case STRAT_BWMFI:
      return ea.StrategyAdd<Stg_BWMFI>(_tfs, _magic_no, _stg);
    case STRAT_BANDS:
      return ea.StrategyAdd<Stg_Bands>(_tfs, _magic_no, _stg);
    case STRAT_BEARS_POWER:
      return ea.StrategyAdd<Stg_BearsPower>(_tfs, _magic_no, _stg);
    case STRAT_BULLS_POWER:
      return ea.StrategyAdd<Stg_BullsPower>(_tfs, _magic_no, _stg);
    case STRAT_CCI:
      return ea.StrategyAdd<Stg_CCI>(_tfs, _magic_no, _stg);
    case STRAT_DEMA:
      return ea.StrategyAdd<Stg_DEMA>(_tfs, _magic_no, _stg);
    case STRAT_DEMARKER:
      return ea.StrategyAdd<Stg_DeMarker>(_tfs, _magic_no, _stg);
    case STRAT_ENVELOPES:
      return ea.StrategyAdd<Stg_Envelopes>(_tfs, _magic_no, _stg);
    case STRAT_FORCE:
      return ea.StrategyAdd<Stg_Force>(_tfs, _magic_no, _stg);
    case STRAT_FRACTALS:
      return ea.StrategyAdd<Stg_Fractals>(_tfs, _magic_no, _stg);
    case STRAT_GATOR:
      return ea.StrategyAdd<Stg_Gator>(_tfs, _magic_no, _stg);
    case STRAT_HEIKEN_ASHI:
      return ea.StrategyAdd<Stg_HeikenAshi>(_tfs, _magic_no, _stg);
    case STRAT_ICHIMOKU:
      return ea.StrategyAdd<Stg_Ichimoku>(_tfs, _magic_no, _stg);
    case STRAT_MA:
      return ea.StrategyAdd<Stg_MA>(_tfs, _magic_no, _stg);
    case STRAT_MACD:
      return ea.StrategyAdd<Stg_MACD>(_tfs, _magic_no, _stg);
    case STRAT_MFI:
      return ea.StrategyAdd<Stg_MFI>(_tfs, _magic_no, _stg);
    case STRAT_MOMENTUM:
      return ea.StrategyAdd<Stg_Momentum>(_tfs, _magic_no, _stg);
    case STRAT_OBV:
      return ea.StrategyAdd<Stg_OBV>(_tfs, _magic_no, _stg);
    case STRAT_OSMA:
      return ea.StrategyAdd<Stg_OsMA>(_tfs, _magic_no, _stg);
    case STRAT_PATTERN:
      return ea.StrategyAdd<Stg_Pattern>(_tfs, _magic_no, _stg);
    case STRAT_RSI:
      return ea.StrategyAdd<Stg_RSI>(_tfs, _magic_no, _stg);
    case STRAT_RVI:
      return ea.StrategyAdd<Stg_RVI>(_tfs, _magic_no, _stg);
    case STRAT_SAR:
      return ea.StrategyAdd<Stg_SAR>(_tfs, _magic_no, _stg);
    case STRAT_STDDEV:
      return ea.StrategyAdd<Stg_StdDev>(_tfs, _magic_no, _stg);
    case STRAT_STOCHASTIC:
      return ea.StrategyAdd<Stg_Stochastic>(_tfs, _magic_no, _stg);
    case STRAT_WPR:
      return ea.StrategyAdd<Stg_WPR>(_tfs, _magic_no, _stg);
    case STRAT_ZIGZAG:
      return ea.StrategyAdd<Stg_ZigZag>(_tfs, _magic_no, _stg);
  }
  return _stg == STRAT_NONE;
}

/**
 * Deinitialize global class variables.
 */
void DeinitVars() { Object::Delete(ea); }
