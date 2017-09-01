-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2017, Lars Asplund lars.anders.asplund@gmail.com
-------------------------------------------------------------------------------
-- This testbench verifies deprecated interfaces
-------------------------------------------------------------------------------

library vunit_lib;
use vunit_lib.run_pkg.all;

use work.log_levels_pkg.all;
use work.logger_pkg.all;
use work.log_handler_pkg.all;
use work.log_deprecated_pkg.all;
use work.core_pkg.all;
use work.assert_pkg.all;

entity tb_deprecated is
  generic (
    runner_cfg : string);
end entity;

architecture a of tb_deprecated is
begin
  test_runner : process
    variable my_logger, my_logger2, uninitialized_logger : logger_t;
    variable almost_failure : log_level_t := new_log_level("almost_failure", failure - 1);
    variable almost_error : log_level_t := new_log_level("almost_error", error - 1);

    constant deprecated_msg : string :=
      "Using deprecated procedure logger_init. Using best effort mapping to contemporary functionality";

    impure function get_display_handler(logger : logger_t) return log_handler_t is
    begin
      if get_file_name(get_log_handler(logger, 0)) = stdout_file_name then
        return get_log_handler(logger, 0);
      else
        return get_log_handler(logger, 1);
      end if;
    end function;

    impure function get_file_handler(logger : logger_t) return log_handler_t is
    begin
      if get_file_name(get_log_handler(logger, 0)) = stdout_file_name then
        return get_log_handler(logger, 1);
      else
        return get_log_handler(logger, 0);
      end if;
    end function;

    procedure check_stop_level(logger : logger_t; pass_level : log_level_t; stop_level : log_level_t) is
    begin
      log(logger, "Hello world", pass_level);
      mock_core_failure;
      log(logger, "Hello world", stop_level);
      check_and_unmock_core_failure("Stop simulation on log level " & log_level_t'image(stop_level));
      reset_log_count(logger, stop_level);
      reset_log_count(logger, pass_level);
    end;

    procedure check_format(logger : logger_t; handler : log_handler_t; expected : deprecated_log_format_t) is
      variable format : log_format_t;
      variable use_color : boolean;
    begin
      get_format(handler, format, use_color);

      if get_file_name(handler) = stdout_file_name then
        assert_true(use_color);
      else
        assert_true(not use_color);
      end if;

      if expected = off then
        for l in above_all_log_levels - 1 downto below_all_log_levels + 1 loop
          assert_true(not is_enabled(logger, handler, log_level_t'val(l)),
                      "Level enabled: " & log_level_t'image(log_level_t'val(l)));
        end loop;
      else
        assert_true(format = expected);
        for l in above_all_log_levels - 1 downto below_all_log_levels + 1 loop
          assert_true(is_enabled(logger, handler, log_level_t'val(l)),
                      "Level disabled: " & log_level_t'image(log_level_t'val(l)));
        end loop;
      end if;
    end;

  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      logger_init(my_logger);

      if run("Test log") then
        set_format(display_handler, format => raw);

        mock(default_logger);
        log("Hello world");
        check_only_log(default_logger, "Hello world", info);
        unmock(default_logger);

        mock_core_failure;
        log(uninitialized_logger, "Hello world");
        check_and_unmock_core_failure("Attempt to log to uninitialized logger");

      elsif run("Test initializing logger") then
        mock(default_logger);
        logger_init(my_logger2);
        check_log(default_logger, deprecated_msg, warning);
        check_log(default_logger, "Empty string logger names not supported. Using ""anonymous1""",  warning);
        unmock(default_logger);

        assert_equal(get_name(my_logger2), "anonymous1");

        assert_equal(num_log_handlers(my_logger2), 2);
        assert(get_file_name(get_file_handler(my_logger2)) = "log.csv");
        assert(get_file_name(get_display_handler(my_logger2)) = stdout_file_name);

        check_format(my_logger2, get_display_handler(my_logger2), raw);
        check_format(my_logger2, get_file_handler(my_logger2), off);

        check_stop_level(my_logger, almost_failure, failure);

      elsif run("Test changing logger name") then
        mock(default_logger);
        mock_core_failure;
        logger_init(my_logger, default_src => "my_logger");
        check_log(default_logger, deprecated_msg, warning);
        check_core_failure("Changing logger name is not supported");
        unmock(default_logger);
        unmock_core_failure;
        assert_equal(get_name(my_logger), "anonymous0");

        mock(default_logger);
        mock_core_failure;
        logger_init(default_src => "my_logger");
        check_log(default_logger, deprecated_msg, warning);
        check_core_failure("Changing logger name is not supported");
        unmock(default_logger);
        unmock_core_failure;
        assert_equal(get_name(default_logger), "default");

      elsif run("Test changing file name") then
        mock(default_logger);
        logger_init(my_logger, file_name => "my_logger.csv");
        check_log(default_logger, deprecated_msg, warning);
        unmock(default_logger);
        assert_equal(get_file_name(get_file_handler(my_logger)), "my_logger.csv");

        mock(default_logger);
        logger_init(file_format => csv, file_name => "my_logger.csv");
        check_log(default_logger, deprecated_msg, warning);
        unmock(default_logger);
        assert_equal(get_file_name(file_handler), "my_logger.csv");

      elsif run("Test changing display format") then
        mock(default_logger);
        logger_init(my_logger, display_format => verbose);
        check_log(default_logger, deprecated_msg, warning);
        unmock(default_logger);
        check_format(my_logger, get_display_handler(my_logger), verbose);

        mock(default_logger);
        logger_init(display_format => verbose);
        check_log(default_logger, deprecated_msg, warning);
        unmock(default_logger);
        check_format(default_logger, get_display_handler(default_logger), verbose);

      elsif run("Test changing file format") then
        mock(default_logger);
        logger_init(my_logger, file_format => verbose);
        check_log(default_logger, deprecated_msg, warning);
        unmock(default_logger);
        check_format(my_logger, get_file_handler(my_logger), verbose);

        mock(default_logger);
        logger_init(file_format => verbose);
        check_log(default_logger, deprecated_msg, warning);
        unmock(default_logger);
        check_format(default_logger, get_file_handler(default_logger), verbose);

      elsif run("Test changing stop level") then
        mock(default_logger);
        logger_init(my_logger, stop_level => error);
        check_log(default_logger, deprecated_msg, warning);
        unmock(default_logger);

        check_stop_level(my_logger, almost_error, error);

        mock(default_logger);
        logger_init(stop_level => error);
        check_log(default_logger, deprecated_msg, warning);
        unmock(default_logger);

        check_stop_level(default_logger, almost_error, error);

      elsif run("Test changing separator") then
        mock_core_failure;
        mock(default_logger);
        logger_init(my_logger, separator => ';');
        check_log(default_logger, deprecated_msg, warning);
        check_core_failure("Changing CSV separator is not supported");
        unmock(default_logger);
        unmock_core_failure;

        mock(default_logger);
        mock_core_failure;
        logger_init(separator => ';');
        check_log(default_logger, deprecated_msg, warning);
        check_core_failure("Changing CSV separator is not supported");
        unmock(default_logger);
        unmock_core_failure;

      elsif run("Test changing append") then
        mock_core_failure;
        mock(default_logger);
        logger_init(my_logger, append => true);
        check_log(default_logger, deprecated_msg, warning);
        check_core_failure("Appending new log to existing file is not supported");
        unmock(default_logger);
        unmock_core_failure;

        mock_core_failure;
        mock(default_logger);
        logger_init(append => true);
        check_log(default_logger, deprecated_msg, warning);
        check_core_failure("Appending new log to existing file is not supported");
        unmock(default_logger);
        unmock_core_failure;

      end if;
    end loop;

    test_runner_cleanup(runner);
  end process;
end architecture;
