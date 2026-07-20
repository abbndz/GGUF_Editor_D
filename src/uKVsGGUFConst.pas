unit uKVsGGUFConst;

interface

uses
  System.Generics.Collections, System.Classes,
  StrUtils, // Nécessaire pour ReplaceStr, ContainsStr, EndsWithStr, StartsWithStr
  SysUtils; // Nécessaire pour les fonctions ANSI si nécessaire

type
  TGGUFKeyFamily = (kfCustom = 0, // Index 0 pour l'UI "Custom"
    kfGeneral, // Index 1
    kfLLM, kfAttention, kfRope, kfTokenizer, kfAdapter, kfCLIPVision, kfCLIPAudio, kfDiffusion, kfSplit, kfSSM,
    kfIMatrix, kfHyperConnection, kfWKV, kfPosNet, kfConvNext, kfClassifier, kfShortConv, kfKDA
    // Note: L'ordre ci-dessus est important pour mapper avec le tableau FKeys.
    // kfGeneral est à l'index 1, kfLLM à 2, etc.
    );

  TGGUFKeyFamilyInfo = record
    DisplayName: string;
    PrefixTemplate: string;
  end;

  TGGUFKeyManager = class
  private
    class var FKeyFamilies: TArray<TGGUFKeyFamilyInfo>;
    class var FInitialized: Boolean;
    class var FKeys: TArray<TArray<string>>;

    class procedure Initialize; static;
  public
    class function GetFamilyNames0: TArray<string>; static;
    class function GetFamilyNames: TStringList;
    class function GetKeysForFamily(const Family: TGGUFKeyFamily; const Architecture: string): TStringList; static;
    class function GetFamilyForKey(const Key: string): TGGUFKeyFamily; static;
    class function FormatKey(const Template: string; const Architecture: string): string; static;
  end;

implementation

{ Helper pour initialiser les records }
procedure InitFamilyInfo(var Info: TGGUFKeyFamilyInfo; const DName: string; const Prefix: string);
begin
  Info.DisplayName := DName;
  Info.PrefixTemplate := Prefix;
end;
{ TGGUFKeyManager }

class procedure TGGUFKeyManager.Initialize;
begin
  if FInitialized then
    Exit;

  // 1. Initialisation des familles
  SetLength(FKeyFamilies, 20); // 19 familles (Autre , kfGeneral à kfKDA)

  // Initialisation explicite champ par champ
  // InitFamilyInfo(FKeyFamilies[Integer(kfGeneral)], '(Autre)', '');
  InitFamilyInfo(FKeyFamilies[Integer(kfGeneral)], 'General', 'general.');
  InitFamilyInfo(FKeyFamilies[Integer(kfLLM)], 'LLM', '{arch}.');
  InitFamilyInfo(FKeyFamilies[Integer(kfAttention)], 'Attention', '{arch}.attention.');
  InitFamilyInfo(FKeyFamilies[Integer(kfRope)], 'RoPE', '{arch}.rope.');
  InitFamilyInfo(FKeyFamilies[Integer(kfTokenizer)], 'Tokenizer', 'tokenizer.');
  InitFamilyInfo(FKeyFamilies[Integer(kfAdapter)], 'Adapter', 'adapter.');
  InitFamilyInfo(FKeyFamilies[Integer(kfCLIPVision)], 'CLIP Vision', 'clip.vision.');
  InitFamilyInfo(FKeyFamilies[Integer(kfCLIPAudio)], 'CLIP Audio', 'clip.audio.');
  InitFamilyInfo(FKeyFamilies[Integer(kfDiffusion)], 'Diffusion', 'diffusion.');
  InitFamilyInfo(FKeyFamilies[Integer(kfSplit)], 'Split', 'split.');
  InitFamilyInfo(FKeyFamilies[Integer(kfSSM)], 'SSM', '{arch}.ssm.');
  InitFamilyInfo(FKeyFamilies[Integer(kfIMatrix)], 'iMatrix', 'imatrix.');
  InitFamilyInfo(FKeyFamilies[Integer(kfHyperConnection)], 'Hyper Connection', '{arch}.hyper_connection.');
  InitFamilyInfo(FKeyFamilies[Integer(kfWKV)], 'WKV', '{arch}.wkv.');
  InitFamilyInfo(FKeyFamilies[Integer(kfPosNet)], 'PosNet', '{arch}.posnet.');
  InitFamilyInfo(FKeyFamilies[Integer(kfConvNext)], 'ConvNext', '{arch}.convnext.');
  InitFamilyInfo(FKeyFamilies[Integer(kfClassifier)], 'Classifier', '{arch}.classifier.');
  InitFamilyInfo(FKeyFamilies[Integer(kfShortConv)], 'ShortConv', '{arch}.shortconv.');
  InitFamilyInfo(FKeyFamilies[Integer(kfKDA)], 'KDA', '{arch}.kda.');

  // 2. Initialisation des clés par famille
  SetLength(FKeys, 20); // 0..19

  // kfCustom (0) - Vide
  SetLength(FKeys[Integer(kfCustom)], 0);

  // kfGeneral (1)
  SetLength(FKeys[Integer(kfGeneral)], 41);
  FKeys[Integer(kfGeneral)][0] := 'general.type';
  FKeys[Integer(kfGeneral)][1] := 'general.architecture';
  FKeys[Integer(kfGeneral)][2] := 'general.quantization_version';
  FKeys[Integer(kfGeneral)][3] := 'general.alignment';
  FKeys[Integer(kfGeneral)][4] := 'general.file_type';
  FKeys[Integer(kfGeneral)][5] := 'general.sampling.sequence';
  FKeys[Integer(kfGeneral)][6] := 'general.sampling.top_k';
  FKeys[Integer(kfGeneral)][7] := 'general.sampling.top_p';
  FKeys[Integer(kfGeneral)][8] := 'general.sampling.min_p';
  FKeys[Integer(kfGeneral)][9] := 'general.sampling.xtc_probability';
  FKeys[Integer(kfGeneral)][10] := 'general.sampling.xtc_threshold';
  FKeys[Integer(kfGeneral)][11] := 'general.sampling.temp';
  FKeys[Integer(kfGeneral)][12] := 'general.sampling.penalty_last_n';
  FKeys[Integer(kfGeneral)][13] := 'general.sampling.penalty_repeat';
  FKeys[Integer(kfGeneral)][14] := 'general.sampling.mirostat';
  FKeys[Integer(kfGeneral)][15] := 'general.sampling.mirostat_tau';
  FKeys[Integer(kfGeneral)][16] := 'general.sampling.mirostat_eta';
  FKeys[Integer(kfGeneral)][17] := 'general.name';
  FKeys[Integer(kfGeneral)][18] := 'general.author';
  FKeys[Integer(kfGeneral)][19] := 'general.version';
  FKeys[Integer(kfGeneral)][20] := 'general.organization';
  FKeys[Integer(kfGeneral)][21] := 'general.finetune';
  FKeys[Integer(kfGeneral)][22] := 'general.basename';
  FKeys[Integer(kfGeneral)][23] := 'general.description';
  FKeys[Integer(kfGeneral)][24] := 'general.quantized_by';
  FKeys[Integer(kfGeneral)][25] := 'general.size_label';
  FKeys[Integer(kfGeneral)][26] := 'general.license';
  FKeys[Integer(kfGeneral)][27] := 'general.license.name';
  FKeys[Integer(kfGeneral)][28] := 'general.license.link';
  FKeys[Integer(kfGeneral)][29] := 'general.url';
  FKeys[Integer(kfGeneral)][30] := 'general.doi';
  FKeys[Integer(kfGeneral)][31] := 'general.uuid';
  FKeys[Integer(kfGeneral)][32] := 'general.repo_url';
  FKeys[Integer(kfGeneral)][33] := 'general.source.url';
  FKeys[Integer(kfGeneral)][34] := 'general.source.doi';
  FKeys[Integer(kfGeneral)][35] := 'general.source.uuid';
  FKeys[Integer(kfGeneral)][36] := 'general.source.repo_url';
  FKeys[Integer(kfGeneral)][37] := 'general.base_model.count';
  FKeys[Integer(kfGeneral)][38] := 'general.tags';
  FKeys[Integer(kfGeneral)][39] := 'general.languages';
  FKeys[Integer(kfGeneral)][40] := 'general.base_model.{id}.name';

  // kfLLM (2)
  SetLength(FKeys[Integer(kfLLM)], 18);
  FKeys[Integer(kfLLM)][0] := '{arch}.vocab_size';
  FKeys[Integer(kfLLM)][1] := '{arch}.context_length';
  FKeys[Integer(kfLLM)][2] := '{arch}.embedding_length';
  FKeys[Integer(kfLLM)][3] := '{arch}.embedding_length_out';
  FKeys[Integer(kfLLM)][4] := '{arch}.features_length';
  FKeys[Integer(kfLLM)][5] := '{arch}.block_count';
  FKeys[Integer(kfLLM)][6] := '{arch}.feed_forward_length';
  FKeys[Integer(kfLLM)][7] := '{arch}.use_parallel_residual';
  FKeys[Integer(kfLLM)][8] := '{arch}.tensor_data_layout';
  FKeys[Integer(kfLLM)][9] := '{arch}.expert_count';
  FKeys[Integer(kfLLM)][10] := '{arch}.moe_every_n_layers';
  FKeys[Integer(kfLLM)][11] := '{arch}.moe_latent_size';
  FKeys[Integer(kfLLM)][12] := '{arch}.hidden_activation';
  FKeys[Integer(kfLLM)][13] := '{arch}.rescale_every_n_layers';
  FKeys[Integer(kfLLM)][14] := '{arch}.norm_before_residual';
  FKeys[Integer(kfLLM)][15] := '{arch}.swiglu_clamp_exp';
  FKeys[Integer(kfLLM)][16] := '{arch}.swiglu_clamp_shexp';
  FKeys[Integer(kfLLM)][17] := '{arch}.block_size';

  // kfAttention (3)
  SetLength(FKeys[Integer(kfAttention)], 25);
  FKeys[Integer(kfAttention)][0] := '{arch}.attention.head_count';
  FKeys[Integer(kfAttention)][1] := '{arch}.attention.head_count_kv';
  FKeys[Integer(kfAttention)][2] := '{arch}.attention.max_alibi_bias';
  FKeys[Integer(kfAttention)][3] := '{arch}.attention.clamp_kqv';
  FKeys[Integer(kfAttention)][4] := '{arch}.attention.key_length';
  FKeys[Integer(kfAttention)][5] := '{arch}.attention.value_length';
  FKeys[Integer(kfAttention)][6] := '{arch}.attention.layer_norm_epsilon';
  FKeys[Integer(kfAttention)][7] := '{arch}.attention.layer_norm_rms_epsilon';
  FKeys[Integer(kfAttention)][8] := '{arch}.attention.causal';
  FKeys[Integer(kfAttention)][9] := '{arch}.attention.sliding_window';
  FKeys[Integer(kfAttention)][10] := '{arch}.attention.scale';
  FKeys[Integer(kfAttention)][11] := '{arch}.attention.output_group_count';
  FKeys[Integer(kfAttention)][12] := '{arch}.attention.output_lora_rank';
  FKeys[Integer(kfAttention)][13] := '{arch}.attention.output_scale';
  FKeys[Integer(kfAttention)][14] := '{arch}.attention.value_scale';
  FKeys[Integer(kfAttention)][15] := '{arch}.attention.compress_ratios';
  FKeys[Integer(kfAttention)][16] := '{arch}.attention.compress_rope_freq_base';
  FKeys[Integer(kfAttention)][17] := '{arch}.attention.temperature_length';
  FKeys[Integer(kfAttention)][18] := '{arch}.attention.key_length_mla';
  FKeys[Integer(kfAttention)][19] := '{arch}.attention.value_length_mla';
  FKeys[Integer(kfAttention)][20] := '{arch}.attention.key_length_swa';
  FKeys[Integer(kfAttention)][21] := '{arch}.attention.value_length_swa';
  FKeys[Integer(kfAttention)][22] := '{arch}.attention.shared_kv_layers';
  FKeys[Integer(kfAttention)][23] := '{arch}.attention.sliding_window_pattern';
  FKeys[Integer(kfAttention)][24] := '{arch}.attention.temperature_scale';

  // kfRope (4)
  SetLength(FKeys[Integer(kfRope)], 16);
  FKeys[Integer(kfRope)][0] := '{arch}.rope.dimension_count';
  FKeys[Integer(kfRope)][1] := '{arch}.rope.dimension_count_swa';
  FKeys[Integer(kfRope)][2] := '{arch}.rope.dimension_sections';
  FKeys[Integer(kfRope)][3] := '{arch}.rope.freq_base';
  FKeys[Integer(kfRope)][4] := '{arch}.rope.freq_base_swa';
  FKeys[Integer(kfRope)][5] := '{arch}.rope.scaling.type';
  FKeys[Integer(kfRope)][6] := '{arch}.rope.scaling.factor';
  FKeys[Integer(kfRope)][7] := '{arch}.rope.scaling.alpha';
  FKeys[Integer(kfRope)][8] := '{arch}.rope.scaling.attn_factor';
  FKeys[Integer(kfRope)][9] := '{arch}.rope.scaling.original_context_length';
  FKeys[Integer(kfRope)][10] := '{arch}.rope.scaling.finetuned';
  FKeys[Integer(kfRope)][11] := '{arch}.rope.scaling.yarn_log_multiplier';
  FKeys[Integer(kfRope)][12] := '{arch}.rope.scaling.yarn_ext_factor';
  FKeys[Integer(kfRope)][13] := '{arch}.rope.scaling.yarn_attn_factor';
  FKeys[Integer(kfRope)][14] := '{arch}.rope.scaling.yarn_beta_fast';
  FKeys[Integer(kfRope)][15] := '{arch}.rope.scaling.yarn_beta_slow';

  // kfTokenizer (5)
  SetLength(FKeys[Integer(kfTokenizer)], 36);
  FKeys[Integer(kfTokenizer)][0] := 'tokenizer.ggml.model';
  FKeys[Integer(kfTokenizer)][1] := 'tokenizer.ggml.pre';
  FKeys[Integer(kfTokenizer)][2] := 'tokenizer.ggml.tokens';
  FKeys[Integer(kfTokenizer)][3] := 'tokenizer.ggml.token_type';
  FKeys[Integer(kfTokenizer)][4] := 'tokenizer.ggml.token_type_count';
  FKeys[Integer(kfTokenizer)][5] := 'tokenizer.ggml.scores';
  FKeys[Integer(kfTokenizer)][6] := 'tokenizer.ggml.merges';
  FKeys[Integer(kfTokenizer)][7] := 'tokenizer.ggml.bos_token_id';
  FKeys[Integer(kfTokenizer)][8] := 'tokenizer.ggml.eos_token_id';
  FKeys[Integer(kfTokenizer)][9] := 'tokenizer.ggml.eot_token_id';
  FKeys[Integer(kfTokenizer)][10] := 'tokenizer.ggml.eom_token_id';
  FKeys[Integer(kfTokenizer)][11] := 'tokenizer.ggml.unknown_token_id';
  FKeys[Integer(kfTokenizer)][12] := 'tokenizer.ggml.seperator_token_id';
  FKeys[Integer(kfTokenizer)][13] := 'tokenizer.ggml.padding_token_id';
  FKeys[Integer(kfTokenizer)][14] := 'tokenizer.ggml.mask_token_id';
  FKeys[Integer(kfTokenizer)][15] := 'tokenizer.ggml.add_bos_token';
  FKeys[Integer(kfTokenizer)][16] := 'tokenizer.ggml.add_eos_token';
  FKeys[Integer(kfTokenizer)][17] := 'tokenizer.ggml.add_sep_token';
  FKeys[Integer(kfTokenizer)][18] := 'tokenizer.ggml.add_space_prefix';
  FKeys[Integer(kfTokenizer)][19] := 'tokenizer.ggml.remove_extra_whitespaces';
  FKeys[Integer(kfTokenizer)][20] := 'tokenizer.ggml.precompiled_charsmap';
  FKeys[Integer(kfTokenizer)][21] := 'tokenizer.ggml.suppress_tokens';
  FKeys[Integer(kfTokenizer)][22] := 'tokenizer.huggingface.json';
  FKeys[Integer(kfTokenizer)][23] := 'tokenizer.rwkv.world';
  FKeys[Integer(kfTokenizer)][24] := 'tokenizer.chat_template';
  FKeys[Integer(kfTokenizer)][25] := 'tokenizer.chat_template.{name}';
  FKeys[Integer(kfTokenizer)][26] := 'tokenizer.chat_templates';
  FKeys[Integer(kfTokenizer)][27] := 'tokenizer.ggml.normalizer.lowercase';
  FKeys[Integer(kfTokenizer)][28] := 'tokenizer.ggml.normalizer.strip_accents';
  FKeys[Integer(kfTokenizer)][29] := 'tokenizer.ggml.fim_pre_token_id';
  FKeys[Integer(kfTokenizer)][30] := 'tokenizer.ggml.fim_suf_token_id';
  FKeys[Integer(kfTokenizer)][31] := 'tokenizer.ggml.fim_mid_token_id';
  FKeys[Integer(kfTokenizer)][32] := 'tokenizer.ggml.fim_pad_token_id';
  FKeys[Integer(kfTokenizer)][33] := 'tokenizer.ggml.fim_rep_token_id';
  FKeys[Integer(kfTokenizer)][34] := 'tokenizer.ggml.fim_sep_token_id';

  // kfAdapter (6)
  SetLength(FKeys[Integer(kfAdapter)], 5);
  FKeys[Integer(kfAdapter)][0] := 'adapter.type';
  FKeys[Integer(kfAdapter)][1] := 'adapter.lora.alpha';
  FKeys[Integer(kfAdapter)][2] := 'adapter.lora.task_name';
  FKeys[Integer(kfAdapter)][3] := 'adapter.lora.prompt_prefix';
  FKeys[Integer(kfAdapter)][4] := 'adapter.alora.invocation_tokens';

  // kfCLIPVision (7)
  SetLength(FKeys[Integer(kfCLIPVision)], 34);
  FKeys[Integer(kfCLIPVision)][0] := 'clip.projector_type';
  FKeys[Integer(kfCLIPVision)][1] := 'clip.has_vision_encoder';
  FKeys[Integer(kfCLIPVision)][2] := 'clip.has_audio_encoder';
  FKeys[Integer(kfCLIPVision)][3] := 'clip.has_llava_projector';
  FKeys[Integer(kfCLIPVision)][4] := 'clip.vision.image_size';
  FKeys[Integer(kfCLIPVision)][5] := 'clip.vision.image_min_pixels';
  FKeys[Integer(kfCLIPVision)][6] := 'clip.vision.image_max_pixels';
  FKeys[Integer(kfCLIPVision)][7] := 'clip.vision.patch_size';
  FKeys[Integer(kfCLIPVision)][8] := 'clip.vision.embedding_length';
  FKeys[Integer(kfCLIPVision)][9] := 'clip.vision.feed_forward_length';
  FKeys[Integer(kfCLIPVision)][10] := 'clip.vision.projection_dim';
  FKeys[Integer(kfCLIPVision)][11] := 'clip.vision.block_count';
  FKeys[Integer(kfCLIPVision)][12] := 'clip.vision.image_mean';
  FKeys[Integer(kfCLIPVision)][13] := 'clip.vision.image_std';
  FKeys[Integer(kfCLIPVision)][14] := 'clip.vision.spatial_merge_size';
  FKeys[Integer(kfCLIPVision)][15] := 'clip.vision.use_gelu';
  FKeys[Integer(kfCLIPVision)][16] := 'clip.vision.use_silu';
  FKeys[Integer(kfCLIPVision)][17] := 'clip.vision.n_wa_pattern';
  FKeys[Integer(kfCLIPVision)][18] := 'clip.vision.wa_layer_indexes';
  FKeys[Integer(kfCLIPVision)][19] := 'clip.vision.wa_pattern_mode';
  FKeys[Integer(kfCLIPVision)][20] := 'clip.vision.is_deepstack_layers';
  FKeys[Integer(kfCLIPVision)][21] := 'clip.vision.window_size';
  FKeys[Integer(kfCLIPVision)][22] := 'clip.vision.feature_layer';
  FKeys[Integer(kfCLIPVision)][23] := 'clip.vision.image_grid_pinpoints';
  FKeys[Integer(kfCLIPVision)][24] := 'clip.vision.attention.head_count';
  FKeys[Integer(kfCLIPVision)][25] := 'clip.vision.attention.head_count_kv';
  FKeys[Integer(kfCLIPVision)][26] := 'clip.vision.attention.layer_norm_epsilon';
  FKeys[Integer(kfCLIPVision)][27] := 'clip.vision.projector.scale_factor';
  FKeys[Integer(kfCLIPVision)][28] := 'clip.vision.projector.query_side';
  FKeys[Integer(kfCLIPVision)][29] := 'clip.vision.projector.window_side';
  FKeys[Integer(kfCLIPVision)][30] := 'clip.vision.projector.spatial_offsets';
  FKeys[Integer(kfCLIPVision)][31] := 'clip.vision.sam.block_count';
  FKeys[Integer(kfCLIPVision)][32] := 'clip.vision.sam.embedding_length';
  FKeys[Integer(kfCLIPVision)][33] := 'clip.vision.sam.head_count';

  // kfCLIPAudio (8)
  SetLength(FKeys[Integer(kfCLIPAudio)], 16);
  FKeys[Integer(kfCLIPAudio)][0] := 'clip.audio.projector_type';
  FKeys[Integer(kfCLIPAudio)][1] := 'clip.audio.num_mel_bins';
  FKeys[Integer(kfCLIPAudio)][2] := 'clip.audio.embedding_length';
  FKeys[Integer(kfCLIPAudio)][3] := 'clip.audio.feed_forward_length';
  FKeys[Integer(kfCLIPAudio)][4] := 'clip.audio.projection_dim';
  FKeys[Integer(kfCLIPAudio)][5] := 'clip.audio.block_count';
  FKeys[Integer(kfCLIPAudio)][6] := 'clip.audio.chunk_size';
  FKeys[Integer(kfCLIPAudio)][7] := 'clip.audio.conv_kernel_size';
  FKeys[Integer(kfCLIPAudio)][8] := 'clip.audio.max_pos_emb';
  FKeys[Integer(kfCLIPAudio)][9] := 'clip.audio.feature_layer';
  FKeys[Integer(kfCLIPAudio)][10] := 'clip.audio.attention.head_count';
  FKeys[Integer(kfCLIPAudio)][11] := 'clip.audio.attention.layer_norm_epsilon';
  FKeys[Integer(kfCLIPAudio)][12] := 'clip.audio.projector.stack_factor';
  FKeys[Integer(kfCLIPAudio)][13] := 'clip.audio.projector.window_size';
  FKeys[Integer(kfCLIPAudio)][14] := 'clip.audio.projector.downsample_rate';
  FKeys[Integer(kfCLIPAudio)][15] := 'clip.audio.projector.head_count';

  // kfDiffusion (9)
  SetLength(FKeys[Integer(kfDiffusion)], 1);
  FKeys[Integer(kfDiffusion)][0] := 'diffusion.shift_logits';

  // kfSplit (10)
  SetLength(FKeys[Integer(kfSplit)], 3);
  FKeys[Integer(kfSplit)][0] := 'split.no';
  FKeys[Integer(kfSplit)][1] := 'split.count';
  FKeys[Integer(kfSplit)][2] := 'split.tensors.count';

  // kfSSM (11)
  SetLength(FKeys[Integer(kfSSM)], 6);
  FKeys[Integer(kfSSM)][0] := '{arch}.ssm.conv_kernel';
  FKeys[Integer(kfSSM)][1] := '{arch}.ssm.inner_size';
  FKeys[Integer(kfSSM)][2] := '{arch}.ssm.state_size';
  FKeys[Integer(kfSSM)][3] := '{arch}.ssm.time_step_rank';
  FKeys[Integer(kfSSM)][4] := '{arch}.ssm.group_count';
  FKeys[Integer(kfSSM)][5] := '{arch}.ssm.dt_b_c_rms';

  // kfIMatrix (12)
  SetLength(FKeys[Integer(kfIMatrix)], 3);
  FKeys[Integer(kfIMatrix)][0] := 'imatrix.chunk_count';
  FKeys[Integer(kfIMatrix)][1] := 'imatrix.chunk_size';
  FKeys[Integer(kfIMatrix)][2] := 'imatrix.datasets';

  // kfHyperConnection (13)
  SetLength(FKeys[Integer(kfHyperConnection)], 3);
  FKeys[Integer(kfHyperConnection)][0] := '{arch}.hyper_connection.count';
  FKeys[Integer(kfHyperConnection)][1] := '{arch}.hyper_connection.sinkhorn_iterations';
  FKeys[Integer(kfHyperConnection)][2] := '{arch}.hyper_connection.epsilon';

  // kfWKV (14)
  SetLength(FKeys[Integer(kfWKV)], 1);
  FKeys[Integer(kfWKV)][0] := '{arch}.wkv.head_size';

  // kfPosNet (15)
  SetLength(FKeys[Integer(kfPosNet)], 2);
  FKeys[Integer(kfPosNet)][0] := '{arch}.posnet.embedding_length';
  FKeys[Integer(kfPosNet)][1] := '{arch}.posnet.block_count';

  // kfConvNext (16)
  SetLength(FKeys[Integer(kfConvNext)], 2);
  FKeys[Integer(kfConvNext)][0] := '{arch}.convnext.embedding_length';
  FKeys[Integer(kfConvNext)][1] := '{arch}.convnext.block_count';

  // kfClassifier (17)
  SetLength(FKeys[Integer(kfClassifier)], 1);
  FKeys[Integer(kfClassifier)][0] := '{arch}.classifier.output_labels';

  // kfShortConv (18)
  SetLength(FKeys[Integer(kfShortConv)], 1);
  FKeys[Integer(kfShortConv)][0] := '{arch}.shortconv.l_cache';

  // kfKDA (19)
  SetLength(FKeys[Integer(kfKDA)], 1);
  FKeys[Integer(kfKDA)][0] := '{arch}.kda.head_dim';

  FInitialized := True;
end;

class function TGGUFKeyManager.GetFamilyNames0: TArray<string>;
var
  I: Integer;
begin
  Initialize;
  // Index 0 = "Autre", puis les 19 familles
  SetLength(Result, 20);
  Result[0] := '(Autre)';
  for I := Low(FKeyFamilies) to High(FKeyFamilies) do
    Result[I + 1] := FKeyFamilies[I].DisplayName;
end;

class function TGGUFKeyManager.GetFamilyNames: TStringList;
var
  I: Integer;
begin
  Initialize;
  // Index 0 = "Autre", puis les 19 familles   *
  Result := TStringList.Create;
  Result.Add('(Autre)');
  for I := Low(FKeyFamilies) + 1 to High(FKeyFamilies) do
    Result.Add(FKeyFamilies[I].DisplayName);
end;

class function TGGUFKeyManager.FormatKey(const Template: string; const Architecture: string): string;
begin
  if Architecture = '' then
    Result := Template
  else
    Result := Template.Replace('{arch}', Architecture);
end;

class function TGGUFKeyManager.GetKeysForFamily(const Family: TGGUFKeyFamily; const Architecture: string): TStringList;
var
  I: Integer;
begin
  Initialize;
  Result := TStringList.Create;

  if Family = kfCustom then
    Exit;

  // Vérifier que l'index de l'énumération est valide par rapport à FKeys
  // FKeys est indexé par Integer(Family)
  if (Integer(Family) >= Low(FKeys)) and (Integer(Family) <= High(FKeys)) then
  begin
    for I := Low(FKeys[Integer(Family)]) to High(FKeys[Integer(Family)]) do
    begin
      Result.Add(FormatKey(FKeys[Integer(Family)][I], Architecture));
    end;
  end;
end;

class function TGGUFKeyManager.GetFamilyForKey(const Key: string): TGGUFKeyFamily;
var
  I: Integer;
  Prefix: string;
  CheckKey: string;
begin
  Initialize;
  Result := kfCustom;

  // Vérifier les préfixes
  for I := Low(FKeyFamilies) to High(FKeyFamilies) do
  begin
    Prefix := FKeyFamilies[I].PrefixTemplate;

    // Remplacer {arch} dans le préfixe pour obtenir le suffixe à rechercher
    CheckKey := Prefix.Replace('{arch}', '');

    if Prefix.Contains('{arch}') then
    begin
      // Pour les préfixes avec {arch}, on vérifie si la clé se termine par ce suffixe
      // Utilisation de EndsWithStr de SysUtils/StrUtils
      if EndsStr(Key, CheckKey) then
      begin
        Result := TGGUFKeyFamily(I + 1); // +1 car kfCustom est 0
        Exit;
      end;
    end
    else
    begin
      // Préfixe fixe : on vérifie si la clé commence par le préfixe
      // Utilisation de StartsWithStr de SysUtils/StrUtils
      if StartsStr(Key, Prefix) then
      begin
        Result := TGGUFKeyFamily(I + 1);
        Exit;
      end;
    end;
  end;
end;

end.
