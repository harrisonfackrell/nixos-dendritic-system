{ self, inputs, ... }:
{
  flake.nixosModules.llamaswap = { config, pkgs, lib, ... }:
    {
      services.llama-swap = {
        enable = true;
        openFirewall = true;
        listenAddress = "0.0.0.0";
        port = 5001;
        settings = let
          llama-cpp = pkgs.llama-cpp-vulkan;
          llama-server = lib.getExe' llama-cpp "llama-server";
          # Roleplaying
          meromero-sparse = pkgs.fetchurl {
            url = "https://huggingface.co/zerofata/G4-MeroMero-26B-A4B-gguf/resolve/main/G4-MeroMero-26B-A4B-Q6_K.gguf";
            sha256 = "d507f52a54b21fd3b3a0579a7154be4a9ea77e4ee01b5f6eaaff287e863f48e9";
          };
          glistening-gem-dense = pkgs.fetchurl {
            url = "https://huggingface.co/mradermacher/Glistening-Gem-31B-v2.1-i1-GGUF/resolve/main/Glistening-Gem-31B-v2.1.i1-Q6_K.gguf";
            sha256 = "a3b3c66e333021e387d52a62111deec2e617df6f7e9f3384b7ac7057abd83332";
          };
          # General Productivity
          gemma4-sparse = pkgs.fetchurl {
            url = "https://huggingface.co/unsloth/gemma-4-26B-A4B-it-qat-GGUF/resolve/main/gemma-4-26B-A4B-it-qat-UD-Q4_K_XL.gguf";
            sha256 = "a7c5bc715f5ff8e99a3e8901ce7d2b42b402c669bf24f7c5250747633d0f5891";
          };
          gemma4-sparse-mmproj = pkgs.fetchurl {
            url = "https://huggingface.co/unsloth/gemma-4-26B-A4B-it-qat-GGUF/resolve/main/mmproj-F32.gguf";
            sha256 = "ef269e294502d6ee3722cbf129681b2586c2e6ceb79d0507963c92146e058cd4";
          };
          gemma4-sparse-mtp = pkgs.fetchurl {
            url = "https://huggingface.co/unsloth/gemma-4-26B-A4B-it-qat-GGUF/resolve/main/mtp-gemma-4-26B-A4B-it.gguf";
            sha256 = "7272d97595f0d4c74bd7b623492b7dbdaafd8b7c72f329a8270ba4eca68f768a";
          };
          gemma4-dense = pkgs.fetchurl {
            url = "https://huggingface.co/unsloth/gemma-4-31B-it-qat-GGUF/resolve/main/gemma-4-31B-it-qat-UD-Q4_K_XL.gguf";
            sha256 = "00b5a7c497f0c8934033088c10a7fa9a4c015e46ee6d89e9c6890650ba5d0e71";
          };
          gemma4-dense-mmproj = pkgs.fetchurl {
            url = "https://huggingface.co/unsloth/gemma-4-31B-it-qat-GGUF/resolve/main/mmproj-F32.gguf";
            sha256 = "7a890d25bbc0a2ce70c3723ad57092d4a5ad98bb2115ed80561f990003c6e88a";
          };
          gemma4-dense-mtp = pkgs.fetchurl {
            url = "https://huggingface.co/unsloth/gemma-4-31B-it-qat-GGUF/resolve/main/mtp-gemma-4-31B-it.gguf";
            sha256 = "3a5e99fd8d0b23afb1fccd1ee0c9ebd1f571d00399c2dae2292d217feeec0f6b";
          };
          # Programming
          qwen38-dense = pkgs.fetchurl {
            url = "https://huggingface.co/unsloth/Qwen3.8-27B-GGUF/resolve/main/Qwen3.8-27B-UD-Q5_K_XL.gguf";
            sha256 = "8601193d3d5760c37fb8ce1b43afebc69df5fb24e1fbc5a547c32e2200305276";
          };
          qwen38-dense-mmproj = pkgs.fetchurl {
            url = "https://huggingface.co/unsloth/Qwen3.8-27B-GGUF/resolve/main/mmproj-BF16.gguf";
            sha256 = "83ee4f4f205fa514161778c41df1ea14144faa0f713510893b63c2395f5c2d53";
          };
          qwen36-sparse = pkgs.fetchurl {
            url = "https://huggingface.co/Jackrong/Qwopus3.6-35B-A3B-Coder-MTP-GGUF/resolve/main/Qwopus3.6-35B-A3B-Coder-MTP-Q5_K_M.gguf";
            sha256 = "b163e7cd4e8efef6f5fba979935e1b1b1a6db0f1330bf7ff129c87250d25e972";
          };
          qwen36-sparse-mmproj = pkgs.fetchurl {
            url = "https://huggingface.co/Jackrong/Qwopus3.6-35B-A3B-Coder-MTP-GGUF/resolve/main/mmproj-F32.gguf";
            sha256 = "5c82c8095717b39f29c88ebfec3607a10307785b1e14a87744603d6c582cd497";
          };
        in {
          healthCheckTimeout = 60;
          models = {
            # Roleplaying
            "MeroMero Sparse" = {
              cmd = "${llama-server} --no-ui -np 1 -ctxcp 16 -cram 4096 --fit-target 0 --port $\{PORT\} --jinja -m ${meromero-sparse} --mmproj ${gemma4-sparse-mmproj}";
              filters = {
                setParams = {
                  temperature = 0.9;
                  min_p = 0.05;
                  chat_template_kwargs = {
                    enable_thinking = false;
                  };
                };
                setParamsByID = {
                  "$\{MODEL_ID\} (Thinking)" = {
                    chat_template_kwargs = {
                      enable_thinking = true;
                    };
                  };
                  "$\{MODEL_ID\} (Instruct)" = {
                    chat_template_kwargs = {
                      enable_thinking = false;
                    };
                  };
                };
              };
            };
            "GlisteningGem Dense" = {
              cmd = "${llama-server} --no-ui -np 1 -ctxcp 1 -cram 8192 -ctv q8_0 -ctk q8_0 --fit-target 0 --port $\{PORT\} --jinja -m ${glistening-gem-dense} --mmproj ${gemma4-dense-mmproj}";
              filters = {
                setParams = {
                  temperature = 0.8;
                  min_p = 0.1;
                  adaptive_target = 0.6;
                  adaptive_decay = 0.75;
                  dry_multiplier = 0.8;
                  dry_base = 1.8;
                  dry_allowed_length = 6;
                  # adaptive-p is not in the default chain; must be listed explicitly to activate it
                  samplers = [ "penalties" "dry" "top_n_sigma" "top_k" "typ_p" "top_p" "min_p" "xtc" "temperature" "adaptive_p" ];
                  chat_template_kwargs = {
                    enable_thinking = false;
                  };
                };
                setParamsByID = {
                  "$\{MODEL_ID\} (Thinking)" = {
                    chat_template_kwargs = {
                      enable_thinking = true;
                    };
                  };
                  "$\{MODEL_ID\} (Instruct)" = {
                    chat_template_kwargs = {
                      enable_thinking = false;
                    };
                  };
                };
              };
            };
            # General Productivity
            "Gemma4 Sparse" = {
              cmd = "${llama-server} --no-ui -np 1 -ctxcp 16 -cram 4096 --fit-target 0 --port $\{PORT\} --jinja -m ${gemma4-sparse} --mmproj ${gemma4-sparse-mmproj} --spec-type draft-mtp -md ${gemma4-sparse-mtp}";
              filters = {
                setParams = {
                  temperature = 1.0;
                  top_p = 0.95;
                  top_k = 64;
                  chat_template_kwargs = {
                    enable_thinking = false;
                  };
                };
                setParamsByID = {
                  "$\{MODEL_ID\} (Thinking)" = {
                    chat_template_kwargs = {
                      enable_thinking = true;
                    };
                  };
                  "$\{MODEL_ID\} (Instruct)" = {
                    chat_template_kwargs = {
                      enable_thinking = false;
                    };
                  };
                };
              };
            };
            "Gemma4 Dense" = {
              cmd = "${llama-server} --no-ui -np 1 -ctxcp 16 -cram 4096 --fit-target 0 --port $\{PORT\} --jinja -m ${gemma4-dense} --mmproj ${gemma4-dense-mmproj} --spec-type draft-mtp -md ${gemma4-dense-mtp}";
              filters = {
                setParams = {
                  temperature = 1.0;
                  top_p = 0.95;
                  top_k = 64;
                  chat_template_kwargs = {
                    enable_thinking = true;
                  };
                };
                setParamsByID = {
                  "$\{MODEL_ID\} (Thinking)" = {
                    chat_template_kwargs = {
                      enable_thinking = true;
                    };
                  };
                  "$\{MODEL_ID\} (Instruct)" = {
                    chat_template_kwargs = {
                      enable_thinking = false;
                    };
                  };
                };
              };
            };
            # Programming
            "Qwen3.8 Dense" = {
              cmd = "${llama-server} --no-ui -np 1 -ctxcp 16 -cram 4096 --fit-target 0 --port $\{PORT\} --jinja -m ${qwen38-dense} --mmproj ${qwen38-dense-mmproj} --spec-type draft-mtp --spec-draft-n-max 3";
              filters = {
                setParams = {
                  temperature = 1.0;
                  top_p = 0.95;
                  top_k = 20;
                  min_p = 0.0;
                  presence_penalty = 0.0;
                  repetition_penalty = 1.0;
                  chat_template_kwargs = {
                    enable_thinking = true;
                    preserve_thinking = true;
                    reasoning_effort = "medium";
                  };
                };
                setParamsByID = {
                  "$\{MODEL_ID\} (Thinking)" = {
                    temperature = 1.0;
                    top_p = 0.95;
                    top_k = 20;
                    min_p = 0.0;
                    presence_penalty = 0.0;
                    repetition_penalty = 1.0;
                    chat_template_kwargs = {
                      enable_thinking = true;
                      preserve_thinking = true;
                      reasoning_effort = "medium";
                    };
                  };
                  "$\{MODEL_ID\} (Instruct)" = {
                    temperature = 0.7;
                    top_p = 0.80;
                    top_k = 20;
                    min_p = 0.0;
                    presence_penalty = 1.5;
                    repetition_penalty = 1.0;
                    chat_template_kwargs = {
                      enable_thinking = false;
                    };
                  };
                };
              };
            };
            "Qwen3.6 Sparse" = {
              cmd = "${llama-server} --no-ui -np 1 -ctxcp 16 -cram 4096 --fit-target 0 --port $\{PORT\} --jinja -m ${qwen36-sparse} --mmproj ${qwen36-sparse-mmproj} --spec-type draft-mtp --spec-draft-n-max 3";
              filters = {
                setParams = {
                  temperature = 0.7;
                  top_p = 0.80;
                  top_k = 20;
                  min_p = 0.0;
                  presence_penalty = 1.5;
                  repetition_penalty = 1.0;
                  chat_template_kwargs = {
                    enable_thinking = false;
                  };
                };
                setParamsByID = {
                  "$\{MODEL_ID\} (Thinking)" = {
                    temperature = 1.0;
                    top_p = 0.95;
                    top_k = 20;
                    min_p = 0.0;
                    presence_penalty = 0.5;
                    repetition_penalty = 1.0;
                    chat_template_kwargs = {
                      enable_thinking = true;
                      preserve_thinking = true;
                    };
                  };
                  "$\{MODEL_ID\} (Instruct)" = {
                    temperature = 0.7;
                    top_p = 0.80;
                    top_k = 20;
                    min_p = 0.0;
                    presence_penalty = 1.5;
                    repetition_penalty = 1.0;
                    chat_template_kwargs = {
                      enable_thinking = false;
                    };
                  };
                };
              };
            };
          };
          hooks.on_startup.preload = [ "" ];
        };
      };
      systemd.services.llama-swap = {
        serviceConfig = {
          DynamicUser = lib.mkForce false;
          LimitMEMLOCK = "infinity";
        };
      };
    };
}
