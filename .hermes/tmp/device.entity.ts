import { Entity, Column, Index, PrimaryGeneratedColumn, CreateDateColumn, UpdateDateColumn, ManyToOne, JoinColumn } from 'typeorm';
import { UserEntity } from './user.entity';

@Entity('devices')
export class DeviceEntity {
  @PrimaryGeneratedColumn({ type: 'int' })
  id: number;

  @Index('idx_user_token')
  @Column({ type: 'varchar', length: 64, name: 'user_token' })
  user_token: string;

  @Index('idx_device_id', { unique: true })
  @Column({ type: 'varchar', length: 128, name: 'device_id' })
  device_id: string;

  @Column({ type: 'varchar', length: 50, nullable: true })
  brand: string;

  @Column({ type: 'varchar', length: 50, nullable: true })
  manufacturer: string;

  @Column({ type: 'varchar', length: 100, name: 'device_model' })
  device_model: string;

  @Column({ type: 'boolean', name: 'is_physical_device', default: true })
  is_physical_device: boolean;

  @Column({ type: 'json', nullable: true, name: 'supported_abis' })
  supported_abis: string[];

  @Column({ type: 'varchar', length: 20, name: 'os_version' })
  os_version: string;

  @Column({ type: 'varchar', length: 10 })
  platform: string;

  @Column({ type: 'varchar', length: 128, nullable: true, name: 'local_token_hash' })
  local_token_hash: string;

  @CreateDateColumn({ type: 'timestamp', name: 'created_at' })
  created_at: Date;

  @UpdateDateColumn({ type: 'timestamp', name: 'last_active_at' })
  last_active_at: Date;

  @ManyToOne(() => UserEntity, (user) => user.devices, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_token', referencedColumnName: 'internal_token' })
  user: UserEntity;
}
